/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/modules/1070%20Procedures/z.usp_RestartTaskQueueBatch.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/docs/readme.md#batch-lifecycle

Changes task-batch lifecycle state under the batch semaphore.
Uses a short transaction and the batch semaphore for atomic mutation.
A successful nested call leaves its caller transaction open; errors roll back the
active transaction. The procedure does not change transaction session settings.
*/
create or alter procedure z.usp_RestartTaskQueueBatch
(
	@BatchID bigint = null,
	@BatchName nvarchar(128) = null
)
as
begin
	set nocount on;
	declare @ActionID uniqueidentifier = newid(), @Slot int, @BatchSemaphore nvarchar(200), @ExecutionID uniqueidentifier = newid(), @Now datetime2(7) = sysutcdatetime();
	begin try
		begin tran;
		exec z.usp_ResolveTaskQueueBatch @BatchID = @BatchID output, @BatchName = @BatchName;
		select @BatchSemaphore = N'z.TaskQueue.Batch:' + convert(nvarchar(20), @BatchID);
		exec @Slot = z.usp_AcquireSemaphore @SemaphoreName = @BatchSemaphore, @TotalCount = 1, @LockOwner = 'Transaction';
		if @Slot <= 0 throw 50000, 'Cannot acquire the TaskQueue batch semaphore.', 1;
		exec z.usp_ValidateTaskQueueBatch @BatchID = @BatchID, @RequireIdle = 1, @ValidateCommands = 1;
		exec z.usp_SetTaskQueueAction @Action = N'Restart', @ActionID = @ActionID;
		-- Publish the new execution identity before resetting tasks so their audit rows use it.
		update z.TaskQueueBatch set Status = 'Ready', ExecutionID = @ExecutionID, LastErrorMessage = null,
			StartedAtUTC = null, FinishedAtUTC = null where BatchID = @BatchID;
		update z.TaskQueueTasks set Status = 'Pending', AttemptsStarted = 0, AvailableAtUTC = @Now,
			ClaimToken = null, WorkerSessionID = null, WorkerLoginTime = null,
			StartedAtUTC = null, FinishedAtUTC = null, LastErrorNumber = null, LastErrorMessage = null
		where BatchID = @BatchID;
		commit;
		exec z.usp_SetTaskQueueAction;
	end try
	begin catch
		if @@trancount > 0 rollback;
		exec z.usp_SetTaskQueueAction;
		throw;
	end catch;
end;
