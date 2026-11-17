/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/modules/1070%20Procedures/z.usp_TaskQueueRunWorker.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/docs/readme.md#worker-and-execution-ownership

Acquires and calls executor procedures with unchanged parameters, serializing each batch's claims and protecting live executions.
Records task outcomes and waits for pending work without changing batch state.
*/
create or alter procedure z.usp_TaskQueueRunWorker
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
	declare	@ResolvedBatchID bigint, @WorkerLoginTime datetime,
			@WorkBatchID bigint, @ScanAfterBatchID bigint, @ExecutionLevel bigint,
			@TaskBatchID bigint, @TaskID int, @ExecutorProcedure nvarchar(300), @Parameters nvarchar(max), @ClaimToken uniqueidentifier,
			@TaskSemaphore nvarchar(200), @Slot int, @ReleaseResult int, @TaskLockHeld bit = 0,
			@RecoveryBatchID bigint, @RecoveryTaskID int, @RecoverySemaphore nvarchar(200), @RecoveryLockHeld bit = 0,
			@CommandServer sysname, @CommandDatabase sysname, @CommandSchema sysname, @CommandProcedure sysname,
			@IsTemporary bit, @ExecutableCommand nvarchar(max), @Sql nvarchar(max),
			@Position int, @PartStart int, @PartCount int, @InBrackets bit, @InQuotes bit, @Character nchar(1),
			@ReturnCode int, @ErrorNumber int, @ErrorMessage nvarchar(4000), @Now datetime2(7),
			@RetryIntervalSecond int, @Failed bit, @CleanupFailed bit = 0, @WaitForWork bit = 0,
			@AuditAction nvarchar(32), @ActionID uniqueidentifier;
	declare @ExecutorParts table(PartIndex int, IsSupplied bit);
	if @BatchName is not null
	begin
		select	@ResolvedBatchID = BatchID from z.TaskQueueBatch where BatchName = @BatchName;
		if @ResolvedBatchID is null throw 50000, 'The named TaskQueue batch does not exist.', 1;
		if @BatchID is not null and @BatchID <> @ResolvedBatchID
			throw 50000, 'BatchID and BatchName identify different batches.', 1;
		select	@BatchID = @ResolvedBatchID;
	end;
	if @BatchID is not null and not exists (select 1 from z.TaskQueueBatch where BatchID = @BatchID)
		throw 50000, 'The specified TaskQueue batch does not exist.', 1;
	select	@WorkerLoginTime = login_time from sys.dm_exec_sessions where session_id = @@spid;
	if @WorkerLoginTime is null throw 50000, 'Cannot identify the worker session.', 1;
	exec sys.sp_set_session_context @key = N'z.TaskQueue.WorkerActive', @value = 1;
	begin try
		while 1 = 1
		begin
			select	@WorkBatchID = null, @TaskBatchID = null, @TaskID = null, @TaskSemaphore = null;
			if @BatchID is not null
			begin
				select	top (1) @WorkBatchID = b.BatchID
				from z.TaskQueueBatch b
				where b.BatchID = @BatchID and (@ScanAfterBatchID is null or b.BatchID > @ScanAfterBatchID)
					and (b.Status in ('Ready', 'Running')
						or exists (select 1 from z.TaskQueueTasks t where t.BatchID = b.BatchID and t.Status = 'Running'));
			end
			else
			begin
				select	top (1) @WorkBatchID = s.BatchID
				from
				(
					select	b.BatchID from z.TaskQueueBatch b
					where b.Status in ('Ready', 'Running') and (@ScanAfterBatchID is null or b.BatchID > @ScanAfterBatchID)
					union
					select	t.BatchID from z.TaskQueueTasks t
					where t.Status = 'Running' and (@ScanAfterBatchID is null or t.BatchID > @ScanAfterBatchID)
				) s
				order by s.BatchID;
			end;
			if @WorkBatchID is null
			begin
				if @WaitForWork = 0 break;
				-- Keep the invocation alive across retry delays, capacity and level waits.
				-- No transaction or batch semaphore is held while waiting.
				exec z.usp_TaskQueueSetAction;
				select	@ScanAfterBatchID = null, @WaitForWork = 0;
				waitfor delay '00:00:01';
				continue;
			end;
			begin tran;
			exec z.usp_TaskQueueLockBatchForChange @BatchID = @WorkBatchID;

			-- Holding the task semaphore is authoritative. Session identifiers are diagnostic.
			declare cRecovery cursor local fast_forward for
				select	BatchID, TaskID from z.TaskQueueTasks
				where Status = 'Running' and BatchID = @WorkBatchID
				order by BatchID, TaskID;
			open cRecovery;
			fetch next from cRecovery into @RecoveryBatchID, @RecoveryTaskID;
			while @@fetch_status = 0
			begin
				select	@RecoverySemaphore = N'z.TaskQueue.Task:' + convert(nvarchar(20), @RecoveryBatchID) + N':' + convert(nvarchar(11), @RecoveryTaskID);
				-- The helper reuses same-session slots. Never adopt an interrupted own execution.
				if applock_mode('public', N'1-' + @RecoverySemaphore, 'Session') = 'NoLock'
				begin
					exec @Slot = z.usp_AcquireSemaphore @SemaphoreName = @RecoverySemaphore, @TotalCount = 1, @LockOwner = 'Session', @LockTimeout = 0;
					if @Slot > 0
					begin
						select	@RecoveryLockHeld = 1;
						select	@ActionID = newid();
						exec z.usp_TaskQueueSetAction @Action = N'Recover', @ActionID = @ActionID;
						update z.TaskQueueTasks
						set Status = 'NeedsReview', FinishedAtUTC = sysutcdatetime(), ClaimToken = null,
							WorkerSessionID = null, WorkerLoginTime = null, LastErrorNumber = 50000,
							LastErrorMessage = N'Execution ownership was lost. The command may have completed; reconcile its effects before retrying.'
						where BatchID = @RecoveryBatchID and TaskID = @RecoveryTaskID and Status = 'Running';
						exec @ReleaseResult = z.usp_ReleaseSemaphore @SemaphoreName = @RecoverySemaphore;
						if @ReleaseResult < 0 throw 50000, 'Cannot release a recovered TaskQueue semaphore.', 1;
						select	@RecoveryLockHeld = 0;
					end;
				end;
				fetch next from cRecovery into @RecoveryBatchID, @RecoveryTaskID;
			end;
			close cRecovery;
			deallocate cRecovery;

			-- Wait for live owners even when dispatch has been stopped.
			if exists (select 1 from z.TaskQueueTasks where BatchID = @WorkBatchID and Status = 'Running')
				select	@WaitForWork = 1;
			-- Reject stopped/saturated batches before searching their pending work.
			if exists
			(
				select	1 from z.TaskQueueBatch b
				where b.BatchID = @WorkBatchID and b.Status in ('Ready', 'Running')
					and (b.MaxConcurrentWorkers = 0 or (select count_big(*) from z.TaskQueueTasks r where r.BatchID = b.BatchID and r.Status = 'Running') < b.MaxConcurrentWorkers)
			)
			begin
				select	@ExecutionLevel = min(s.SortOrder)
				from
				(
					select	min(SortOrder) SortOrder from z.TaskQueueTasks where BatchID = @WorkBatchID and CompletionState = 0
					union all
					select	min(SortOrder) from z.TaskQueueTasks where BatchID = @WorkBatchID and CompletionState = 1
				) s;
				-- Future availability keeps the worker alive; terminal level barriers do not.
				if exists
				(
					select	1 from z.TaskQueueTasks
					where BatchID = @WorkBatchID and SortOrder = @ExecutionLevel and CompletionState = 0
						and Status in ('Pending', 'Failed')
						and convert(bigint, AttemptsStarted) < convert(bigint, MaxRetries) + 1
						and (Status = 'Pending' or AttemptsStarted > 0)
				) select @WaitForWork = 1;
				-- The gate keeps capacity and the earliest unresolved level stable through acquisition.
				select	top (1) @TaskBatchID = BatchID, @TaskID = TaskID
				from z.v_TaskQueuePendingTasks
				where BatchID = @WorkBatchID and SortOrder = @ExecutionLevel
				order by BatchID, SortOrder, TaskID;
				if @TaskID is not null
					select	@ExecutorProcedure = ExecutorProcedure, @Parameters = Parameters, @RetryIntervalSecond = RetryIntervalSecond
					from z.TaskQueueTasks where BatchID = @TaskBatchID and TaskID = @TaskID;
			end;
			if @TaskID is null
			begin
				commit;
				exec z.usp_TaskQueueSetAction;
				select	@ScanAfterBatchID = @WorkBatchID;
				continue;
			end;
			select	@ActionID = newid();
			exec z.usp_TaskQueueSetAction @Action = N'Acquire', @ActionID = @ActionID;
			if exists (select 1 from z.TaskQueueTasks where BatchID = @TaskBatchID and TaskID = @TaskID and AttemptsStarted = 2147483647)
			begin
				update z.TaskQueueTasks set Status = 'NeedsReview', LastErrorNumber = 50000,
					LastErrorMessage = N'The task attempt counter cannot be incremented.'
				where BatchID = @TaskBatchID and TaskID = @TaskID;
				commit;
				exec z.usp_TaskQueueSetAction;
				select	@ScanAfterBatchID = null, @WaitForWork = 0;
				continue;
			end;
			select	@TaskSemaphore = N'z.TaskQueue.Task:' + convert(nvarchar(20), @TaskBatchID) + N':' + convert(nvarchar(11), @TaskID);
			if applock_mode('public', N'1-' + @TaskSemaphore, 'Session') <> 'NoLock'
				throw 50000, 'The current session retains an interrupted task lock; disconnect before reuse.', 1;
			exec @Slot = z.usp_AcquireSemaphore @SemaphoreName = @TaskSemaphore, @TotalCount = 1, @LockOwner = 'Session', @LockTimeout = 0;
			if @Slot <= 0
			begin
				commit;
				exec z.usp_TaskQueueSetAction;
				select	@ScanAfterBatchID = @WorkBatchID;
				continue;
			end;
			select	@TaskLockHeld = 1, @ClaimToken = newid(), @Now = sysutcdatetime();
			update z.TaskQueueTasks set Status = 'Running', AttemptsStarted = AttemptsStarted + 1,
				ClaimToken = @ClaimToken, WorkerSessionID = @@spid, WorkerLoginTime = @WorkerLoginTime,
				StartedAtUTC = @Now, FinishedAtUTC = null
			where BatchID = @TaskBatchID and TaskID = @TaskID and Status in ('Pending', 'Failed');
			if @@rowcount <> 1 throw 50000, 'The selected task could not be claimed.', 1;
			commit;
			exec z.usp_TaskQueueSetAction;

			select	@Failed = 0, @ErrorNumber = null, @ErrorMessage = null;
			begin try
				delete from @ExecutorParts;
				-- Count supplied parts without treating quoted dots as name separators.
				-- PARSENAME returns NULL for oversized parts; never drop a supplied qualifier.
				select	@Position = 1, @PartStart = 1, @PartCount = 1, @InBrackets = 0, @InQuotes = 0;
				while @Position <= len(@ExecutorProcedure)
				begin
					select	@Character = substring(@ExecutorProcedure, @Position, 1);
					if @InBrackets = 1
					begin
						if @Character = N']' and substring(@ExecutorProcedure, @Position + 1, 1) = N']' select @Position = @Position + 1;
						else if @Character = N']' select @InBrackets = 0;
					end
					else if @InQuotes = 1
					begin
						if @Character = N'"' and substring(@ExecutorProcedure, @Position + 1, 1) = N'"' select @Position = @Position + 1;
						else if @Character = N'"' select @InQuotes = 0;
					end
					else if @Character = N'[' select @InBrackets = 1;
					else if @Character = N'"' select @InQuotes = 1;
					else if @Character = N'.'
					begin
						insert @ExecutorParts values (@PartCount, iif(len(trim(substring(@ExecutorProcedure, @PartStart, @Position - @PartStart))) > 0, 1, 0));
						select	@PartCount = @PartCount + 1, @PartStart = @Position + 1;
					end;
					select	@Position = @Position + 1;
				end;
				insert @ExecutorParts values (@PartCount, iif(len(trim(substring(@ExecutorProcedure, @PartStart, len(@ExecutorProcedure)))) > 0, 1, 0));
				select	@CommandServer = parsename(@ExecutorProcedure, 4), @CommandDatabase = parsename(@ExecutorProcedure, 3),
						@CommandSchema = parsename(@ExecutorProcedure, 2), @CommandProcedure = parsename(@ExecutorProcedure, 1),
						@IsTemporary = iif(left(parsename(@ExecutorProcedure, 1), 2) = N'##' and parsename(@ExecutorProcedure, 2) is null
							and parsename(@ExecutorProcedure, 3) is null and parsename(@ExecutorProcedure, 4) is null, 1, 0);
				if @PartCount > 4 or exists
				(
					select	1 from @ExecutorParts
					where IsSupplied = 1 and case @PartCount - PartIndex + 1 when 1 then @CommandProcedure when 2 then @CommandSchema
						when 3 then @CommandDatabase when 4 then @CommandServer end is null
				)
					throw 50000, 'An executor procedure name contains an invalid or oversized identifier.', 1;
				if @CommandProcedure is null or (@IsTemporary = 0 and @CommandSchema is null and @CommandDatabase is null and @CommandServer is null)
					throw 50000, 'The executor must name a qualified SQL procedure or a one-part ## procedure.', 1;
				select	@ExecutableCommand = case when @IsTemporary = 1 then N'tempdb..' + quotename(@CommandProcedure)
						else case when @CommandServer is not null then quotename(@CommandServer) + N'.' else N'' end
							+ case when @CommandServer is not null or @CommandDatabase is not null then isnull(quotename(@CommandDatabase), N'') + N'.' else N'' end
							+ isnull(quotename(@CommandSchema), N'') + N'.' + quotename(@CommandProcedure) end;
				select	@Sql = N'exec @Code = ' + @ExecutableCommand + N' @Parameters = @Payload;', @ReturnCode = null;
				exec sys.sp_executesql @Sql, N'@Payload nvarchar(max), @Code int output',
					@Payload = @Parameters, @Code = @ReturnCode output;
				if @@trancount <> 0
				begin
					rollback;
					throw 50000, 'The task returned with an open transaction; it was rolled back.', 1;
				end;
				if isnull(@ReturnCode, 0) <> 0
				begin
					select	@ErrorMessage = N'The task executor returned code ' + convert(nvarchar(11), @ReturnCode) + N'.';
					throw 50000, @ErrorMessage, 1;
				end;
			end try
			begin catch
				select	@Failed = 1, @ErrorNumber = error_number(), @ErrorMessage = error_message();
				if @@trancount > 0 rollback;
			end catch;
			set nocount, xact_abort on;

			begin tran;
			exec z.usp_TaskQueueLockBatchForChange @BatchID = @WorkBatchID;
			select	@ActionID = newid(), @AuditAction = case when @Failed = 1 then N'Fail' else N'Complete' end;
			exec z.usp_TaskQueueSetAction @Action = @AuditAction, @ActionID = @ActionID;
			select	@Now = sysutcdatetime();
			update z.TaskQueueTasks set Status = case when @Failed = 1 then 'Failed' else 'Succeeded' end,
				FinishedAtUTC = @Now, LastErrorNumber = @ErrorNumber, LastErrorMessage = @ErrorMessage,
				AvailableAtUTC = case when @Failed = 1 then dateadd(second, @RetryIntervalSecond, @Now) else AvailableAtUTC end,
				ClaimToken = null, WorkerSessionID = null, WorkerLoginTime = null
			where BatchID = @TaskBatchID and TaskID = @TaskID and Status = 'Running' and ClaimToken = @ClaimToken;
			if @@rowcount <> 1 throw 50000, 'Task completion ownership no longer matches.', 1;
			commit;
			exec @ReleaseResult = z.usp_ReleaseSemaphore @SemaphoreName = @TaskSemaphore;
			if @ReleaseResult < 0 throw 50000, 'Cannot release the completed task semaphore.', 1;
			select	@TaskLockHeld = 0, @ScanAfterBatchID = null, @WaitForWork = 0;
		end;
		exec z.usp_TaskQueueSetAction;
		exec sys.sp_set_session_context @key = N'z.TaskQueue.WorkerActive', @value = null;
	end try
	begin catch
		if @@trancount > 0 rollback;
		exec z.usp_TaskQueueSetAction;
		if cursor_status('local', 'cRecovery') >= 0 close cRecovery;
		if cursor_status('local', 'cRecovery') > -3 deallocate cRecovery;
		if @TaskLockHeld = 1
		begin
			exec @ReleaseResult = z.usp_ReleaseSemaphore @SemaphoreName = @TaskSemaphore;
			if @ReleaseResult < 0 select @CleanupFailed = 1;
		end;
		if @RecoveryLockHeld = 1
		begin
			exec @ReleaseResult = z.usp_ReleaseSemaphore @SemaphoreName = @RecoverySemaphore;
			if @ReleaseResult < 0 select @CleanupFailed = 1;
		end;
		if @CleanupFailed = 0 exec sys.sp_set_session_context @key = N'z.TaskQueue.WorkerActive', @value = null;
		throw;
	end catch;
end;
