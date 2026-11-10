/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/modules/1070%20Procedures/z.usp_StopTaskQueueBatch.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/docs/readme.md#batch-lifecycle

Changes task-batch lifecycle state under the batch semaphore.
Uses a short transaction and the batch semaphore for atomic mutation.
A successful nested call leaves its caller transaction open; errors roll back the
active transaction. The procedure does not change transaction session settings.
*/
create or alter procedure z.usp_StopTaskQueueBatch
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
		if not exists (select 1 from z.TaskQueueBatch where BatchID = @BatchID and Status in ('Ready', 'Running', 'Stopped'))
			throw 50000, 'Only a Ready, Running or Stopped batch can be stopped.', 1;
		exec z.usp_SetTaskQueueAction @Action = N'Stop', @ActionID = @ActionID;
		update z.TaskQueueBatch set Status = 'Stopped', FinishedAtUTC = null where BatchID = @BatchID and Status <> 'Stopped';
		commit;
		exec z.usp_SetTaskQueueAction;
	end try
	begin catch
		if @@trancount > 0 rollback;
		exec z.usp_SetTaskQueueAction;
		throw;
	end catch;
end;
