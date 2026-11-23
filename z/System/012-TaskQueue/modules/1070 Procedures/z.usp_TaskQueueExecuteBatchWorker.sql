/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/modules/1070%20Procedures/z.usp_TaskQueueExecuteBatchWorker.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/docs/readme.md#worker-and-execution-ownership

Acquires and calls executor procedures with unchanged parameters, serializing each batch's claims and protecting live executions.
Works on one resolved Running batch; waits for progress at the first unfinished order and records task outcomes without changing batch state.
*/
create or alter procedure z.usp_TaskQueueExecuteBatchWorker
(
	@BatchID bigint = null,
	@BatchName nvarchar(128) = null
)
as
begin
	set nocount on;
	set xact_abort off;
	if @@trancount <> 0
		throw 50000, 'TaskQueue workers must run outside a transaction.', 1;
	if @@options & 2 = 2
		throw 50000, 'TaskQueue workers require implicit transactions to be disabled.', 1;
	declare	@WorkerLoginTime datetime, @SortOrder bigint, @CanProgress bit,
			@TaskID int, @ExecutorProcedure nvarchar(300), @Parameters nvarchar(max), @ClaimToken uniqueidentifier,
			@TaskSemaphore nvarchar(200), @Slot int, @BatchSemaphore nvarchar(200), @MaxConcurrentWorkers int,
			@ErrorNumber int, @ErrorMessage nvarchar(4000), @Now datetime2(7),
			@RetryIntervalSecond int, @CleanupFailed bit = 0,
			@ActionID uniqueidentifier, @ExecutionID uniqueidentifier;

	exec z.usp_TaskQueueResolveBatch @BatchID = @BatchID output, @BatchName = @BatchName;

	select	@BatchSemaphore = z.fn_TaskQueueGetBatchSemaphore(@BatchID),
			@WorkerLoginTime = login_time
	from sys.dm_exec_sessions
	where session_id = @@spid;

	begin try
		while 1 = 1
		begin
			select	@TaskID = null, @ExecutionID = null, @Slot = 0,
					@ErrorNumber = null, @ErrorMessage = null;
			begin tran;
			exec z.usp_TaskQueueLockBatchForChange @BatchID = @BatchID;
			-- Read the current limit with Running state before recovering or claiming tasks.
			select	@MaxConcurrentWorkers = MaxConcurrentWorkers, @ExecutionID = ExecutionID
			from z.TaskQueueBatch
			where BatchID = @BatchID
				and Status = 'Running';
			if @@rowcount = 0
			begin
				commit;
				break;
			end;
			if isnull(@MaxConcurrentWorkers, 0) < 1
				throw 50000, 'Only a positive worker limit can be executed.', 1;

			-- The batch gate prevents new task owners while unlocked Running rows are recovered.
			select	@ActionID = newid(), @Now = sysutcdatetime();
			exec z.usp_TaskQueueSetAction @Action = N'Recover', @ActionID = @ActionID;
			update t
				set Status = 'Failed', FinishedAtUTC = @Now,
					AvailableAtUTC = dateadd(second, iif(t.RetryIntervalSecond = 0, 1, t.RetryIntervalSecond), @Now), ClaimToken = null,
					WorkerSessionID = null, WorkerLoginTime = null, LastErrorNumber = 50000,
					LastErrorMessage = N'Execution ownership was lost. The attempt failed and follows the configured retry policy; command effects may already have committed.'
			from z.TaskQueueTasks t
				inner join z.v_TaskQueueRunningTasks r on r.BatchID = t.BatchID and r.TaskID = t.TaskID
			where t.BatchID = @BatchID
				and t.Status = 'Running'
				and r.IsTaskLockHeld = 0;
			exec z.usp_TaskQueueSetAction;

			-- Terminal unmet conditions keep their order from being skipped.
			-- Running tasks and candidates admitted by PendingTasks can still progress at this order.
			select	top (1)
					@SortOrder = t.SortOrder,
					@CanProgress = max(
						case
							when t.CompletionState = 0
								and (t.Status <> 'Pending' or t.AttemptsStarted <= t.MaxRetries) then 1
							else 0
						end
					)
			from z.TaskQueueTasks t
			where t.BatchID = @BatchID
				and t.CompletionState in (0, 1)
			group by t.SortOrder
			order by t.SortOrder;
			if @@rowcount = 0 or @CanProgress = 0
			begin
				commit;
				break;
			end;

			select	top (1)
					@TaskID = t.TaskID, @ExecutorProcedure = t.ExecutorProcedure,
					@Parameters = t.Parameters, @RetryIntervalSecond = iif(t.RetryIntervalSecond = 0, 1, t.RetryIntervalSecond)
			from z.v_TaskQueuePendingTasks t
			where t.BatchID = @BatchID
				and t.SortOrder = @SortOrder
				and t.AvailableAtUTC <= sysutcdatetime()
			order by t.TaskID;
			if @TaskID is null
			begin
				commit;
				waitfor delay '00:00:00.300';
				continue;
			end;

			exec @Slot = z.usp_AcquireSemaphore @SemaphoreName = @BatchSemaphore, @TotalCount = @MaxConcurrentWorkers,
				@LockOwner = 'Session', @LockTimeout = 0;
			if @Slot <= 0
			begin
				commit;
				if @Slot <> -1
					break; -- when -999, internal or parameter validation error
				waitfor delay '00:00:01';
				continue;
			end;

			select	@TaskSemaphore = z.fn_TaskQueueGetTaskSemaphore(@BatchID, @TaskID);
			exec @Slot = z.usp_AcquireSemaphore @SemaphoreName = @TaskSemaphore, @TotalCount = 1,
				@LockOwner = 'Session', @LockTimeout = 0;
			if @Slot <= 0
			begin
				commit;
				throw 50000, 'Task could not be locked.', 1;
			end;
			select	@ActionID = newid(), @ClaimToken = newid(), @Now = sysutcdatetime();

			exec z.usp_TaskQueueSetAction @Action = N'ExecuteTask', @ActionID = @ActionID;
			update z.TaskQueueTasks
				set Status = 'Running', AttemptsStarted = AttemptsStarted + 1, ClaimToken = @ClaimToken,
					WorkerSessionID = @@spid, WorkerLoginTime = @WorkerLoginTime,
					StartedAtUTC = @Now, FinishedAtUTC = null
			where BatchID = @BatchID
				and TaskID = @TaskID
				and Status in ('Pending', 'Failed');
			if @@rowcount <> 1
				throw 50000, 'The selected task could not be claimed.', 1;
			commit;
			exec z.usp_TaskQueueSetAction;

			begin try
				exec @ExecutorProcedure @Parameters = @Parameters;
			end try
			begin catch
				select	@ErrorNumber = error_number(), @ErrorMessage = z.fn_GetFullErrorMessage();
				if @@trancount > 0
					rollback;
			end catch;

			begin tran;
			exec z.usp_TaskQueueLockBatchForChange @BatchID = @BatchID;
			exec z.usp_TaskQueueSetAction @Action = N'ExecuteTask', @ActionID = @ActionID;
			select	@Now = sysutcdatetime();
			update z.TaskQueueTasks
				set Status = iif(@ErrorNumber is null, 'Succeeded', 'Failed'),
					FinishedAtUTC = @Now, LastErrorNumber = @ErrorNumber, LastErrorMessage = @ErrorMessage,
					AvailableAtUTC =	case
											when @ErrorNumber is null then AvailableAtUTC
											else dateadd(second, @RetryIntervalSecond, @Now)
										end,
					ClaimToken = null, WorkerSessionID = null, WorkerLoginTime = null
			where BatchID = @BatchID
				and TaskID = @TaskID
				and Status = 'Running'
				and ClaimToken = @ClaimToken;
			if @@rowcount <> 1
				throw 50000, 'Task completion ownership no longer matches.', 1;

			-- Keep the batch gate through both releases and preserve the outcome on a cleanup error.
			exec z.usp_ReleaseSemaphore @SemaphoreName = @TaskSemaphore, @SuppressException = 1;
			exec z.usp_ReleaseSemaphore @SemaphoreName = @BatchSemaphore, @SuppressException = 1;
			commit;
		end;
		exec z.usp_TaskQueueSetAction;
	end try
	begin catch
		if @@trancount > 0
			rollback;
		begin try
			if @ExecutionID is null
			begin
				select	@ExecutionID = ExecutionID from z.TaskQueueBatch where BatchID = @BatchID;
			end;
			insert z.TaskQueueLog (
				BatchID, TaskID, ExecutionID, ActionID, Action, ChangeType,
				LoginName, ApplicationName, HostName, SessionID, AfterJson
			)
			values (
				@BatchID, @TaskID, @ExecutionID, newid(), N'WorkerError', 'Insert',
				original_login(), app_name(), host_name(), @@spid, z.fn_GetFullErrorJson()
			);
		end try
		begin catch
			print concat(N'Could not log worker error for TaskQueue batch ', @BatchID, N'. ', error_message());
		end catch;
		exec z.usp_TaskQueueSetAction;
		exec z.usp_ReleaseSemaphore @SemaphoreName = @TaskSemaphore, @SuppressException = 1;
		exec z.usp_ReleaseSemaphore @SemaphoreName = @BatchSemaphore, @SuppressException = 1;
		throw;
	end catch;
end;
