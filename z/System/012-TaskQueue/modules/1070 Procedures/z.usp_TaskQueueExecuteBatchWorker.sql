/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/modules/1070%20Procedures/z.usp_TaskQueueExecuteBatchWorker.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/docs/readme.md#worker-and-execution-ownership

Acquires and calls executor procedures with unchanged parameters, serializing each batch's claims and protecting live executions.
Works on one resolved Running batch; records task outcomes without changing batch state and returns when no task can be claimed now.
*/
create or alter procedure z.usp_TaskQueueExecuteBatchWorker
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
	declare	@WorkerLoginTime datetime,
			@TaskID int, @AttemptsStarted int, @ExecutorProcedure nvarchar(300), @Parameters nvarchar(max), @ClaimToken uniqueidentifier,
			@TaskSemaphore nvarchar(200), @Slot int, @ReleaseResult int, @TaskLockHeld bit = 0,
			@BatchSemaphore nvarchar(200), @MaxConcurrentWorkers int, @BatchLockHeld bit = 0,
			@CommandServer sysname, @CommandDatabase sysname, @CommandSchema sysname, @CommandProcedure sysname,
			@IsTemporary bit, @ExecutableCommand nvarchar(max), @Sql nvarchar(max),
			@Position int, @PartStart int, @PartCount int, @InBrackets bit, @InQuotes bit, @Character nchar(1),
			@ReturnCode int, @ErrorNumber int, @ErrorMessage nvarchar(4000), @Now datetime2(7),
			@RetryIntervalSecond int, @Failed bit, @CleanupFailed bit = 0,
			@AuditAction nvarchar(32), @ActionID uniqueidentifier;
	
	declare @ExecutorParts table(PartIndex int, IsSupplied bit);
	
	exec z.usp_TaskQueueResolveBatch @BatchID = @BatchID output, @BatchName = @BatchName output;
	select	@BatchSemaphore = z.fn_TaskQueueGetBatchSemaphore(@BatchID);
	
	select	@WorkerLoginTime = login_time 
	from sys.dm_exec_sessions 
	where session_id = @@spid;
	
	exec sys.sp_set_session_context @key = N'z.TaskQueue.WorkerActive', @value = 1;
	begin try
		while 1 = 1
		begin
			select	@TaskID = null, @TaskSemaphore = null;
			begin tran;
			exec z.usp_TaskQueueLockBatchForChange @BatchID = @BatchID;
			-- Read the current limit with Running state before recovering or claiming tasks.
			select	@MaxConcurrentWorkers = MaxConcurrentWorkers
			from z.TaskQueueBatch
			where BatchID = @BatchID and Status = 'Running';
			if @@rowcount = 0
			begin
				commit;
				break;
			end;

			-- The batch gate prevents new task owners while unlocked Running rows are recovered.
			select	@ActionID = newid(), @Now = sysutcdatetime();
			exec z.usp_TaskQueueSetAction @Action = N'Recover', @ActionID = @ActionID;
			update t
			set Status = 'Failed', FinishedAtUTC = @Now,
				AvailableAtUTC = dateadd(second, t.RetryIntervalSecond, @Now), ClaimToken = null,
				WorkerSessionID = null, WorkerLoginTime = null, LastErrorNumber = 50000,
				LastErrorMessage = N'Execution ownership was lost. The attempt failed and follows the configured retry policy; command effects may already have committed.'
			from z.TaskQueueTasks t
				inner join z.v_TaskQueueRunningTasks r on r.BatchID = t.BatchID and r.TaskID = t.TaskID
			where t.BatchID = @BatchID 
				and t.Status = 'Running' 
				and r.IsTaskLockHeld = 0;
			exec z.usp_TaskQueueSetAction;

			-- The worker applies scheduling rules while the gate keeps selection stable through acquisition.
			select	top (1) @TaskID = t.TaskID, @ExecutorProcedure = t.ExecutorProcedure,
					@Parameters = t.Parameters, @RetryIntervalSecond = t.RetryIntervalSecond,
					@AttemptsStarted = t.AttemptsStarted
			from z.v_TaskQueuePendingTasks t
			where t.BatchID = @BatchID and t.AvailableAtUTC <= sysutcdatetime()
				and not exists
				(
					select	1 from z.TaskQueueTasks p
					where p.BatchID = t.BatchID and p.CompletionState in (0, 1) and p.SortOrder < t.SortOrder
				)
			order by t.SortOrder, t.TaskID;
			if @TaskID is null
			begin
				commit;
				break;
			end;
			select	@ActionID = newid();
			exec z.usp_TaskQueueSetAction @Action = N'Acquire', @ActionID = @ActionID;
			if @AttemptsStarted = 2147483647
			begin
				update z.TaskQueueTasks set Status = 'Failed', FinishedAtUTC = sysutcdatetime(), LastErrorNumber = 50000,
					LastErrorMessage = N'The task attempt counter cannot be incremented.'
				where BatchID = @BatchID and TaskID = @TaskID;
				commit;
				exec z.usp_TaskQueueSetAction;
				continue;
			end;
			select	@TaskSemaphore = z.fn_TaskQueueGetTaskSemaphore(@BatchID, @TaskID);
			if applock_mode('public', z.fn_TaskQueueGetTaskSemaphoreSlot(@BatchID, @TaskID), 'Session') <> 'NoLock'
				throw 50000, 'The current session retains an interrupted task lock; disconnect before reuse.', 1;
			exec @Slot = z.usp_AcquireSemaphore @SemaphoreName = @TaskSemaphore, @TotalCount = 1, @LockOwner = 'Session', @LockTimeout = 0;
			if @Slot <= 0
			begin
				commit;
				break;
			end;
			select	@TaskLockHeld = 1;
			if @MaxConcurrentWorkers > 0
			begin
				exec @Slot = z.usp_AcquireSemaphore @SemaphoreName = @BatchSemaphore, @TotalCount = @MaxConcurrentWorkers, @LockOwner = 'Session', @LockTimeout = 0;
				if @Slot <= 0
				begin
					exec @ReleaseResult = z.usp_ReleaseSemaphore @SemaphoreName = @TaskSemaphore;
					if @ReleaseResult < 0 throw 50000, 'Cannot release the unclaimed task semaphore.', 1;
					select	@TaskLockHeld = 0;
					commit;
					break;
				end;
				select	@BatchLockHeld = 1;
			end;
			select	@ClaimToken = newid(), @Now = sysutcdatetime();
			update z.TaskQueueTasks set Status = 'Running', AttemptsStarted = AttemptsStarted + 1,
				ClaimToken = @ClaimToken, WorkerSessionID = @@spid, WorkerLoginTime = @WorkerLoginTime,
				StartedAtUTC = @Now, FinishedAtUTC = null
			where BatchID = @BatchID and TaskID = @TaskID and Status in ('Pending', 'Failed');
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
			exec z.usp_TaskQueueLockBatchForChange @BatchID = @BatchID;
			select	@ActionID = newid(), @AuditAction = case when @Failed = 1 then N'Fail' else N'Complete' end;
			exec z.usp_TaskQueueSetAction @Action = @AuditAction, @ActionID = @ActionID;
			select	@Now = sysutcdatetime();
			update z.TaskQueueTasks set Status = case when @Failed = 1 then 'Failed' else 'Succeeded' end,
				FinishedAtUTC = @Now, LastErrorNumber = @ErrorNumber, LastErrorMessage = @ErrorMessage,
				AvailableAtUTC = case when @Failed = 1 then dateadd(second, @RetryIntervalSecond, @Now) else AvailableAtUTC end,
				ClaimToken = null, WorkerSessionID = null, WorkerLoginTime = null
			where BatchID = @BatchID and TaskID = @TaskID and Status = 'Running' and ClaimToken = @ClaimToken;
			if @@rowcount <> 1 throw 50000, 'Task completion ownership no longer matches.', 1;
			commit;
			exec @ReleaseResult = z.usp_ReleaseSemaphore @SemaphoreName = @TaskSemaphore;
			if @ReleaseResult < 0 throw 50000, 'Cannot release the completed task semaphore.', 1;
			select	@TaskLockHeld = 0;
			if @BatchLockHeld = 1
			begin
				exec @ReleaseResult = z.usp_ReleaseSemaphore @SemaphoreName = @BatchSemaphore;
				if @ReleaseResult < 0 throw 50000, 'Cannot release the batch worker semaphore.', 1;
				select	@BatchLockHeld = 0;
			end;
		end;
		exec z.usp_TaskQueueSetAction;
		exec sys.sp_set_session_context @key = N'z.TaskQueue.WorkerActive', @value = null;
	end try
	begin catch
		if @@trancount > 0 rollback;
		exec z.usp_TaskQueueSetAction;
		if @TaskLockHeld = 1
		begin
			exec @ReleaseResult = z.usp_ReleaseSemaphore @SemaphoreName = @TaskSemaphore;
			if @ReleaseResult < 0 select @CleanupFailed = 1;
		end;
		if @BatchLockHeld = 1
		begin
			exec @ReleaseResult = z.usp_ReleaseSemaphore @SemaphoreName = @BatchSemaphore;
			if @ReleaseResult < 0 select @CleanupFailed = 1;
		end;
		if @CleanupFailed = 0 exec sys.sp_set_session_context @key = N'z.TaskQueue.WorkerActive', @value = null;
		throw;
	end catch;
end;
