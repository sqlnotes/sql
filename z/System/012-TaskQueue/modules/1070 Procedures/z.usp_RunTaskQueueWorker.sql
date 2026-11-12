/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/modules/1070%20Procedures/z.usp_RunTaskQueueWorker.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/docs/readme.md#worker-and-execution-ownership

Acquires and runs stored-procedure tasks, serializing each batch's claims and protecting live executions.
*/
create or alter procedure z.usp_RunTaskQueueWorker
(
	@BatchID bigint = null,
	@BatchName nvarchar(128) = null
)
as
begin
	set nocount, xact_abort on;
	if @@trancount <> 0 throw 50000, 'TaskQueue workers must run outside a transaction.', 1;
	if @@options & 2 = 2 throw 50000, 'TaskQueue workers require implicit transactions to be disabled.', 1;
	if session_context(N'z.TaskQueue.WorkerActive') is not null
		throw 50000, 'This session already has an active or interrupted TaskQueue worker; disconnect it before reuse.', 1;
	declare @ResolvedBatchID bigint, @WorkerLoginTime datetime,
		@WorkBatchID bigint, @ScanAfterBatchID bigint, @ExecutionLevel bigint, @BatchSemaphore nvarchar(200),
		@TaskBatchID bigint, @TaskID int, @TaskBody nvarchar(max), @ClaimToken uniqueidentifier,
		@TaskSemaphore nvarchar(200), @Slot int, @ReleaseResult int, @TaskLockHeld bit = 0,
		@RecoveryBatchID bigint, @RecoveryTaskID int, @RecoverySemaphore nvarchar(200), @RecoveryLockHeld bit = 0,
		@Command nvarchar(4000), @CommandSchema sysname, @CommandProcedure sysname, @CommandID int, @IsTemporary bit, @ExecutableCommand nvarchar(776),
		@Parameters nvarchar(max), @Sql nvarchar(max), @Declarations nvarchar(max), @Arguments nvarchar(max),
		@ParameterIndex int, @ParameterName sysname, @ParameterType nvarchar(128), @VariableName nvarchar(32),
		@ReturnCode int, @ErrorNumber int, @ErrorMessage nvarchar(4000), @Now datetime2(7),
		@RetryIntervalSecond int, @Failed bit, @CleanupFailed bit = 0,
		@AuditAction nvarchar(32), @ActionID uniqueidentifier;
	declare @ParameterMetadata table
	(
		ParameterName sysname, TypeName sysname, MaxLength smallint, Precision tinyint, Scale tinyint
	);
	declare @Bindings table
	(
		ParameterIndex int not null,
		ParameterName nvarchar(4000),
		ValueType int,
		ParameterType nvarchar(128)
	);
	if @BatchName is not null
	begin
		select @ResolvedBatchID = BatchID from z.TaskQueueBatch where BatchName = @BatchName;
		if @ResolvedBatchID is null throw 50000, 'The named TaskQueue batch does not exist.', 1;
		if @BatchID is not null and @BatchID <> @ResolvedBatchID
			throw 50000, 'BatchID and BatchName identify different batches.', 1;
		select @BatchID = @ResolvedBatchID;
	end;
	if @BatchID is not null and not exists (select 1 from z.TaskQueueBatch where BatchID = @BatchID)
		throw 50000, 'The specified TaskQueue batch does not exist.', 1;
	select @WorkerLoginTime = login_time from sys.dm_exec_sessions where session_id = @@spid;
	if @WorkerLoginTime is null throw 50000, 'Cannot identify the worker session.', 1;
	exec sys.sp_set_session_context @key = N'z.TaskQueue.WorkerActive', @value = 1;
	begin try
		while 1 = 1
		begin
			select @WorkBatchID = null, @TaskBatchID = null, @TaskID = null, @TaskSemaphore = null;
			if @BatchID is not null
			begin
				select top (1) @WorkBatchID = b.BatchID
				from z.TaskQueueBatch b
				where b.BatchID = @BatchID and (@ScanAfterBatchID is null or b.BatchID > @ScanAfterBatchID)
					and (b.Status in ('Ready', 'Running')
						or exists (select 1 from z.TaskQueueTasks t where t.BatchID = b.BatchID and t.Status = 'Running'));
			end
			else
			begin
				select top (1) @WorkBatchID = s.BatchID
				from
				(
					select b.BatchID from z.TaskQueueBatch b
					where b.Status in ('Ready', 'Running') and (@ScanAfterBatchID is null or b.BatchID > @ScanAfterBatchID)
					union
					select t.BatchID from z.TaskQueueTasks t
					where t.Status = 'Running' and (@ScanAfterBatchID is null or t.BatchID > @ScanAfterBatchID)
				) s
				order by s.BatchID;
			end;
			if @WorkBatchID is null break;
			select @BatchSemaphore = N'z.TaskQueue.Batch:' + convert(nvarchar(20), @WorkBatchID);
			begin tran;
			exec @Slot = z.usp_AcquireSemaphore @SemaphoreName = @BatchSemaphore, @TotalCount = 1, @LockOwner = 'Transaction';
			if @Slot <= 0 throw 50000, 'Cannot acquire the TaskQueue batch semaphore.', 1;

			-- Holding the task semaphore is authoritative. Session identifiers are diagnostic.
			declare Recovery cursor local fast_forward for
				select BatchID, TaskID from z.TaskQueueTasks
				where Status = 'Running' and BatchID = @WorkBatchID
				order by BatchID, TaskID;
			open Recovery;
			fetch next from Recovery into @RecoveryBatchID, @RecoveryTaskID;
			while @@fetch_status = 0
			begin
				select @RecoverySemaphore = N'z.TaskQueue.Task:' + convert(nvarchar(20), @RecoveryBatchID) + N':' + convert(nvarchar(11), @RecoveryTaskID);
				-- The helper reuses same-session slots. Never adopt an interrupted own execution.
				if applock_mode('public', N'1-' + @RecoverySemaphore, 'Session') = 'NoLock'
				begin
					exec @Slot = z.usp_AcquireSemaphore @SemaphoreName = @RecoverySemaphore, @TotalCount = 1, @LockOwner = 'Session', @LockTimeout = 0;
					if @Slot > 0
					begin
						select @RecoveryLockHeld = 1;
						select @ActionID = newid();
						exec z.usp_SetTaskQueueAction @Action = N'Recover', @ActionID = @ActionID;
						update z.TaskQueueTasks
						set Status = 'NeedsReview', FinishedAtUTC = sysutcdatetime(), ClaimToken = null,
							WorkerSessionID = null, WorkerLoginTime = null, LastErrorNumber = 50000,
							LastErrorMessage = N'Execution ownership was lost. The command may have completed; reconcile its effects before retrying.'
						where BatchID = @RecoveryBatchID and TaskID = @RecoveryTaskID and Status = 'Running';
						update z.TaskQueueBatch set Status = 'Stopped', LastErrorMessage = N'A task lost execution ownership and requires outcome review.', FinishedAtUTC = null
						where BatchID = @RecoveryBatchID and Status in ('Ready', 'Running')
							and not exists (select 1 from z.TaskQueueTasks where BatchID = @RecoveryBatchID and Status = 'Running');
						exec @ReleaseResult = z.usp_ReleaseSemaphore @SemaphoreName = @RecoverySemaphore, @LockOwner = 'Session';
						if @ReleaseResult < 0 throw 50000, 'Cannot release a recovered TaskQueue semaphore.', 1;
						select @RecoveryLockHeld = 0;
					end;
				end;
				fetch next from Recovery into @RecoveryBatchID, @RecoveryTaskID;
			end;
			close Recovery;
			deallocate Recovery;

			-- Terminal unmet conditions stop the batch; a retryable failure is not terminal.
			select @ActionID = newid();
			exec z.usp_SetTaskQueueAction @Action = N'Reconcile', @ActionID = @ActionID;
			update b set Status = 'Stopped', FinishedAtUTC = null,
				LastErrorMessage = coalesce(b.LastErrorMessage, N'A task cannot satisfy its completion condition; review the task outcomes.')
			from z.TaskQueueBatch b
			where b.Status in ('Ready', 'Running') and b.BatchID = @WorkBatchID
				and not exists (select 1 from z.TaskQueueTasks where BatchID = b.BatchID and Status = 'Running')
				and exists
				(
					select 1 from z.TaskQueueTasks t where t.BatchID = b.BatchID
					and t.CompletionState = 1
				);
			update b set Status = 'Completed', FinishedAtUTC = sysutcdatetime()
			from z.TaskQueueBatch b
			where b.Status in ('Ready', 'Running') and b.BatchID = @WorkBatchID
				and not exists
				(
					select 1 from z.TaskQueueTasks t where t.BatchID = b.BatchID
						and t.CompletionState < 2
				);
			-- Reject stopped/saturated batches before searching their pending work.
			if exists
			(
				select 1 from z.TaskQueueBatch b
				where b.BatchID = @WorkBatchID and b.Status in ('Ready', 'Running')
					and (b.MaxConcurrentWorkers = 0 or (select count_big(*) from z.TaskQueueTasks r where r.BatchID = b.BatchID and r.Status = 'Running') < b.MaxConcurrentWorkers)
			)
			begin
				select @ExecutionLevel = min(s.SortOrder)
				from
				(
					select min(SortOrder) SortOrder from z.TaskQueueTasks where BatchID = @WorkBatchID and CompletionState = 0
					union all
					select min(SortOrder) from z.TaskQueueTasks where BatchID = @WorkBatchID and CompletionState = 1
				) s;
				-- The gate keeps capacity and the earliest unresolved level stable through acquisition.
				select top (1) @TaskBatchID = BatchID, @TaskID = TaskID
				from z.v_TaskQueueActiveTasks
				where IsReadyToExecute = 1 and BatchID = @WorkBatchID and SortOrder = @ExecutionLevel
				order by BatchID, SortOrder, TaskID;
				if @TaskID is not null
					select @TaskBody = TaskBody, @RetryIntervalSecond = RetryIntervalSecond
					from z.TaskQueueTasks where BatchID = @TaskBatchID and TaskID = @TaskID;
			end;
			if @TaskID is null
			begin
				commit;
				exec z.usp_SetTaskQueueAction;
				select @ScanAfterBatchID = @WorkBatchID;
				continue;
			end;
			select @ActionID = newid();
			exec z.usp_SetTaskQueueAction @Action = N'Acquire', @ActionID = @ActionID;
			if exists (select 1 from z.TaskQueueTasks where BatchID = @TaskBatchID and TaskID = @TaskID and AttemptsStarted = 2147483647)
			begin
				update z.TaskQueueTasks set Status = 'NeedsReview', LastErrorNumber = 50000,
					LastErrorMessage = N'The task attempt counter cannot be incremented.'
				where BatchID = @TaskBatchID and TaskID = @TaskID;
				commit;
				exec z.usp_SetTaskQueueAction;
				select @ScanAfterBatchID = null;
				continue;
			end;
			select @TaskSemaphore = N'z.TaskQueue.Task:' + convert(nvarchar(20), @TaskBatchID) + N':' + convert(nvarchar(11), @TaskID);
			if applock_mode('public', N'1-' + @TaskSemaphore, 'Session') <> 'NoLock'
				throw 50000, 'The current session retains an interrupted task lock; disconnect before reuse.', 1;
			exec @Slot = z.usp_AcquireSemaphore @SemaphoreName = @TaskSemaphore, @TotalCount = 1, @LockOwner = 'Session', @LockTimeout = 0;
			if @Slot <= 0
			begin
				commit;
				exec z.usp_SetTaskQueueAction;
				select @ScanAfterBatchID = @WorkBatchID;
				continue;
			end;
			select @TaskLockHeld = 1, @ClaimToken = newid(), @Now = sysutcdatetime();
			update z.TaskQueueTasks set Status = 'Running', AttemptsStarted = AttemptsStarted + 1,
				ClaimToken = @ClaimToken, WorkerSessionID = @@spid, WorkerLoginTime = @WorkerLoginTime,
				StartedAtUTC = @Now, FinishedAtUTC = null
			where BatchID = @TaskBatchID and TaskID = @TaskID and Status in ('Pending', 'Failed');
			if @@rowcount <> 1 throw 50000, 'The selected task could not be claimed.', 1;
			update z.TaskQueueBatch set Status = 'Running', StartedAtUTC = coalesce(StartedAtUTC, @Now), FinishedAtUTC = null
			where BatchID = @TaskBatchID and Status in ('Ready', 'Running');
			if @@rowcount <> 1 throw 50000, 'The task batch is no longer executable.', 1;
			commit;
			exec z.usp_SetTaskQueueAction;

			select @Failed = 0, @ErrorNumber = null, @ErrorMessage = null;
			begin try
				-- Procedure metadata supplies executable parameter names and types; JSON values stay bound.
				delete from @Bindings;
				select @Command = json_value(@TaskBody, '$.command'), @Parameters = json_query(@TaskBody, '$.parameters');
				if (select count(*) from openjson(@TaskBody) where [key] = 'command') <> 1
					or not exists (select 1 from openjson(@TaskBody) where [key] = 'command' and [type] = 1)
					or (select count(*) from openjson(@TaskBody) where [key] = 'parameters') <> 1
					or not exists (select 1 from openjson(@TaskBody) where [key] = 'parameters' and [type] = 4)
					throw 50000, 'TaskBody requires one command string and one parameters array.', 1;
				select @CommandSchema = parsename(@Command, 2), @CommandProcedure = parsename(@Command, 1),
					@IsTemporary = iif(left(parsename(@Command, 1), 2) = N'##' and parsename(@Command, 2) is null, 1, 0);
				if @CommandProcedure is null or parsename(@Command, 3) is not null or parsename(@Command, 4) is not null
					or (@IsTemporary = 0 and (@CommandSchema is null or left(@CommandProcedure, 1) = N'#' or left(@Command, 2) = N'##'))
					throw 50000, 'The task command must name a local schema-qualified SQL procedure or a one-part ## procedure.', 1;
				select @ExecutableCommand = case when @IsTemporary = 1 then N'tempdb..' + quotename(@CommandProcedure)
					else quotename(@CommandSchema) + N'.' + quotename(@CommandProcedure) end;
				select @CommandID = object_id(@ExecutableCommand, N'P');
				if @CommandID is null or (@IsTemporary = 0 and @CommandID = @@procid)
					throw 50000, 'The task command must be an existing SQL procedure other than this worker.', 1;
				delete from @ParameterMetadata;
				if @IsTemporary = 1
					insert @ParameterMetadata
						select p.name, y.name, p.max_length, p.precision, p.scale
						from tempdb.sys.parameters p
							join tempdb.sys.types d on d.user_type_id = p.user_type_id and d.is_user_defined = 0 and d.is_table_type = 0
							join tempdb.sys.types y on y.user_type_id = p.system_type_id and y.user_type_id = y.system_type_id
						where p.object_id = @CommandID and p.is_output = 0;
				else
					insert @ParameterMetadata
						select p.name, y.name, p.max_length, p.precision, p.scale
						from sys.parameters p
							join sys.types d on d.user_type_id = p.user_type_id and d.is_user_defined = 0 and d.is_table_type = 0
							join sys.types y on y.user_type_id = p.system_type_id and y.user_type_id = y.system_type_id
						where p.object_id = @CommandID and p.is_output = 0;
				-- Bind under the queue database collation; never choose between ambiguous tempdb names.
				if @IsTemporary = 1 and exists (select ParameterName from @ParameterMetadata group by ParameterName having count(*) > 1)
					throw 50000, 'Temporary procedure parameter names are ambiguous under the queue database collation.', 1;
				if exists (select 1 from openjson(@Parameters) where [type] <> 5)
					throw 50000, 'Each task parameter must be a JSON object.', 1;
				if exists
				(
					select 1 from openjson(@Parameters) p
					where (select count(*) from openjson(p.value) where [key] = 'name') <> 1
						or not exists (select 1 from openjson(p.value) where [key] = 'name' and [type] = 1)
						or (select count(*) from openjson(p.value) where [key] = 'value') <> 1
						or not exists (select 1 from openjson(p.value) where [key] = 'value' and [type] in (0, 1, 2, 3))
				)
					throw 50000, 'Each task parameter requires one name and one scalar or null value.', 1;
				insert @Bindings (ParameterIndex, ParameterName, ValueType)
					select convert(int, p.[key]), case when left(json_value(p.value, '$.name'), 1) = N'@'
						then json_value(p.value, '$.name') else N'@' + json_value(p.value, '$.name') end,
						v.[type]
					from openjson(@Parameters) p
						cross apply openjson(p.value) v
					where v.[key] = 'value';
				if exists (select ParameterName from @Bindings group by ParameterName having count(*) > 1)
					throw 50000, 'Task parameter names must be unique.', 1;
				if exists (select 1 from @Bindings where len(ParameterName) < 2 or len(ParameterName) > 128
					or substring(ParameterName, 2, 4000) collate Latin1_General_100_BIN2 like N'%[^A-Za-z0-9_]%'
					or substring(ParameterName, 2, 1) collate Latin1_General_100_BIN2 like N'[^A-Za-z_]')
					throw 50000, 'Task parameter names must use letters, digits and underscores.', 1;
				update b set ParameterName = p.ParameterName, ParameterType =
					case when p.TypeName in ('varchar', 'char', 'varbinary', 'binary') then p.TypeName + N'(' + case when p.MaxLength = -1 then N'max' else convert(nvarchar(10), p.MaxLength) end + N')'
						when p.TypeName in ('nvarchar', 'nchar') then p.TypeName + N'(' + case when p.MaxLength = -1 then N'max' else convert(nvarchar(10), p.MaxLength / 2) end + N')'
						when p.TypeName in ('decimal', 'numeric') then p.TypeName + N'(' + convert(nvarchar(3), p.Precision) + N',' + convert(nvarchar(3), p.Scale) + N')'
						when p.TypeName in ('datetime2', 'datetimeoffset', 'time') then p.TypeName + N'(' + convert(nvarchar(3), p.Scale) + N')'
						when p.TypeName = 'float' then N'float(' + convert(nvarchar(3), p.Precision) + N')'
						else p.TypeName end
				from @Bindings b
					join @ParameterMetadata p on p.ParameterName = b.ParameterName
				where p.TypeName in ('bigint', 'int', 'smallint', 'tinyint', 'bit', 'decimal', 'numeric', 'money', 'smallmoney',
					'float', 'real', 'date', 'datetime', 'smalldatetime', 'datetime2', 'datetimeoffset', 'time',
					'char', 'varchar', 'nchar', 'nvarchar', 'binary', 'varbinary', 'uniqueidentifier', 'xml');
				if exists (select 1 from @Bindings where ParameterType is null)
					throw 50000, 'A task parameter is unknown, output-only or has an unsupported type.', 1;
				select @Declarations = N'', @Arguments = N'';
				declare Bindings cursor local fast_forward for
					select ParameterIndex, convert(sysname, ParameterName), ParameterType from @Bindings order by ParameterIndex;
				open Bindings;
				fetch next from Bindings into @ParameterIndex, @ParameterName, @ParameterType;
				while @@fetch_status = 0
				begin
					select @VariableName = N'@P' + convert(nvarchar(11), @ParameterIndex);
					select @Declarations = @Declarations + N'declare ' + @VariableName + N' ' + @ParameterType
						+ N'; select ' + @VariableName + N' = convert(' + @ParameterType
						+ N', case when [type] = 0 then null else value end) from openjson(@Body, ''$.parameters['
						+ convert(nvarchar(11), @ParameterIndex) + N']'') where [key] = ''value'';' + nchar(13) + nchar(10),
						@Arguments = @Arguments + case when @Arguments = N'' then N' ' else N', ' end + @ParameterName + N' = ' + @VariableName;
					fetch next from Bindings into @ParameterIndex, @ParameterName, @ParameterType;
				end;
				close Bindings;
				deallocate Bindings;
				select @Sql = @Declarations + N'exec @Code = ' + @ExecutableCommand + @Arguments + N';', @ReturnCode = null;
				exec sys.sp_executesql @Sql, N'@Body nvarchar(max), @Code int output', @Body = @TaskBody, @Code = @ReturnCode output;
				if @@trancount <> 0
				begin
					rollback;
					throw 50000, 'The task returned with an open transaction; it was rolled back.', 1;
				end;
				if isnull(@ReturnCode, 0) <> 0
				begin
					select @ErrorMessage = N'The task procedure returned code ' + convert(nvarchar(11), @ReturnCode) + N'.';
					throw 50000, @ErrorMessage, 1;
				end;
			end try
			begin catch
				select @Failed = 1, @ErrorNumber = error_number(), @ErrorMessage = error_message();
				if @@trancount > 0 rollback;
				if cursor_status('local', 'Bindings') >= 0 close Bindings;
				if cursor_status('local', 'Bindings') > -3 deallocate Bindings;
			end catch;
			set nocount, xact_abort on;

			begin tran;
			exec @Slot = z.usp_AcquireSemaphore @SemaphoreName = @BatchSemaphore, @TotalCount = 1, @LockOwner = 'Transaction';
			if @Slot <= 0 throw 50000, 'Cannot acquire the TaskQueue completion semaphore.', 1;
			select @ActionID = newid(), @AuditAction = case when @Failed = 1 then N'Fail' else N'Complete' end;
			exec z.usp_SetTaskQueueAction @Action = @AuditAction, @ActionID = @ActionID;
			select @Now = sysutcdatetime();
			update z.TaskQueueTasks set Status = case when @Failed = 1 then 'Failed' else 'Succeeded' end,
				FinishedAtUTC = @Now, LastErrorNumber = @ErrorNumber, LastErrorMessage = @ErrorMessage,
				AvailableAtUTC = case when @Failed = 1 then dateadd(second, @RetryIntervalSecond, @Now) else AvailableAtUTC end,
				ClaimToken = null, WorkerSessionID = null, WorkerLoginTime = null
			where BatchID = @TaskBatchID and TaskID = @TaskID and Status = 'Running' and ClaimToken = @ClaimToken;
			if @@rowcount <> 1 throw 50000, 'Task completion ownership no longer matches.', 1;
			if @Failed = 1 update z.TaskQueueBatch set LastErrorMessage = @ErrorMessage where BatchID = @TaskBatchID;
			commit;
			exec @ReleaseResult = z.usp_ReleaseSemaphore @SemaphoreName = @TaskSemaphore, @LockOwner = 'Session';
			if @ReleaseResult < 0 throw 50000, 'Cannot release the completed task semaphore.', 1;
			select @TaskLockHeld = 0, @ScanAfterBatchID = null;
		end;
		exec z.usp_SetTaskQueueAction;
		exec sys.sp_set_session_context @key = N'z.TaskQueue.WorkerActive', @value = null;
	end try
	begin catch
		if @@trancount > 0 rollback;
		exec z.usp_SetTaskQueueAction;
		if cursor_status('local', 'Recovery') >= 0 close Recovery;
		if cursor_status('local', 'Recovery') > -3 deallocate Recovery;
		if @TaskLockHeld = 1
		begin
			exec @ReleaseResult = z.usp_ReleaseSemaphore @SemaphoreName = @TaskSemaphore, @LockOwner = 'Session';
			if @ReleaseResult < 0 select @CleanupFailed = 1;
		end;
		if @RecoveryLockHeld = 1
		begin
			exec @ReleaseResult = z.usp_ReleaseSemaphore @SemaphoreName = @RecoverySemaphore, @LockOwner = 'Session';
			if @ReleaseResult < 0 select @CleanupFailed = 1;
		end;
		if @CleanupFailed = 0 exec sys.sp_set_session_context @key = N'z.TaskQueue.WorkerActive', @value = null;
		throw;
	end catch;
end;
