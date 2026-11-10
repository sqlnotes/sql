/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/modules/1070%20Procedures/z.usp_ResumeTaskQueueBatch.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/docs/readme.md#batch-lifecycle

Changes task-batch lifecycle state under the batch semaphore.
Uses a short transaction and the batch semaphore for atomic mutation.
A successful nested call leaves its caller transaction open; errors roll back the
active transaction. The procedure does not change transaction session settings.
*/
create or alter procedure z.usp_ResumeTaskQueueBatch
(
	@BatchID bigint = null,
	@BatchName nvarchar(128) = null
)
as
begin
	set nocount on;
	declare @ActionID uniqueidentifier = newid(), @Slot int, @BatchSemaphore nvarchar(200);
	begin try
		begin tran;
		exec z.usp_ResolveTaskQueueBatch @BatchID = @BatchID output, @BatchName = @BatchName;
		select @BatchSemaphore = N'z.TaskQueue.Batch:' + convert(nvarchar(20), @BatchID);
		exec @Slot = z.usp_AcquireSemaphore @SemaphoreName = @BatchSemaphore, @TotalCount = 1, @LockOwner = 'Transaction';
		if @Slot <= 0 throw 50000, 'Cannot acquire the TaskQueue batch semaphore.', 1;
		if not exists (select 1 from z.TaskQueueBatch where BatchID = @BatchID and Status = 'Stopped')
			throw 50000, 'Only a Stopped batch can be resumed.', 1;
		exec z.usp_ValidateTaskQueueBatch @BatchID = @BatchID, @RequireIdle = 1, @ValidateCommands = 1;
		if exists
		(
			select 1 from z.TaskQueueTasks where BatchID = @BatchID
				and (Status in ('NeedsReview', 'Blocked')
					or (Status = 'Succeeded' and CompletionCondition = 'Failed')
					or (Status = 'Failed' and CompletionCondition = 'Succeeded' and cast(AttemptsStarted as bigint) >= cast(MaxRetries as bigint) + 1)
					or (Status = 'Pending' and cast(AttemptsStarted as bigint) >= cast(MaxRetries as bigint) + 1))
		)
			throw 50000, 'Unresolved task outcomes prevent resume; reconcile them or explicitly restart the batch.', 1;
		exec z.usp_SetTaskQueueAction @Action = N'Resume', @ActionID = @ActionID;
		update z.TaskQueueBatch set Status = 'Ready', FinishedAtUTC = null where BatchID = @BatchID;
		commit;
		exec z.usp_SetTaskQueueAction;
	end try
	begin catch
		if @@trancount > 0 rollback;
		exec z.usp_SetTaskQueueAction;
		throw;
	end catch;
end;
