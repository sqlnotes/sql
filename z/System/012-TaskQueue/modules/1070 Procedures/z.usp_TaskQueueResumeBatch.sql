/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/modules/1070%20Procedures/z.usp_TaskQueueResumeBatch.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/docs/readme.md#batch-lifecycle

Changes task-batch lifecycle state under the batch semaphore.
Uses a short transaction and the batch semaphore for atomic mutation.
A successful nested call leaves its caller transaction open; errors roll back the
active transaction. The procedure does not change transaction session settings.
*/
create or alter procedure z.usp_TaskQueueResumeBatch
(
	@BatchID bigint = null,
	@BatchName nvarchar(128) = null
)
as
begin
	set nocount on;
	declare @ActionID uniqueidentifier = newid();
	begin try
		begin tran;
		exec z.usp_TaskQueueResolveBatch @BatchID = @BatchID output, @BatchName = @BatchName output;
		exec z.usp_TaskQueueLockBatchForChange @BatchID = @BatchID;
		if not exists (select 1 from z.TaskQueueBatch where BatchID = @BatchID and Status = 'Stopped')
			throw 50000, 'Only a Stopped batch can be resumed.', 1;
		if exists (select 1 from z.v_TaskQueueRunningTasks where BatchID = @BatchID)
			throw 50000, 'The batch has Running tasks; wait for completion or recover ownership before changing it.', 1;
		if exists
		(
			select	1 from z.TaskQueueTasks where BatchID = @BatchID
				and (CompletionState = 1
					or (Status = 'Pending' and cast(AttemptsStarted as bigint) >= cast(MaxRetries as bigint) + 1))
		)
			throw 50000, 'Unresolved task outcomes prevent resume; reconcile them or explicitly restart the batch.', 1;
		exec z.usp_TaskQueueSetAction @Action = N'Resume', @ActionID = @ActionID;
		update z.TaskQueueBatch set Status = 'Ready', FinishedAtUTC = null where BatchID = @BatchID;
		commit;
		exec z.usp_TaskQueueSetAction;
	end try
	begin catch
		if @@trancount > 0 rollback;
		exec z.usp_TaskQueueSetAction;
		throw;
	end catch;
end;
