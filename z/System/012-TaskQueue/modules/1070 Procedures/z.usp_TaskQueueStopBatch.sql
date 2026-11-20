/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/modules/1070%20Procedures/z.usp_TaskQueueStopBatch.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/docs/readme.md#batch-lifecycle

Changes task-batch lifecycle state under the batch semaphore.
Uses a short transaction and the batch semaphore for atomic mutation.
A successful nested call leaves its caller transaction open; errors roll back the
active transaction. The procedure does not change transaction session settings.
*/
create or alter procedure z.usp_TaskQueueStopBatch
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
		exec z.usp_TaskQueueResolveBatch @BatchID = @BatchID output, @BatchName = @BatchName;
		exec z.usp_TaskQueueLockBatchForChange @BatchID = @BatchID;
		if not exists (select 1 from z.TaskQueueBatch where BatchID = @BatchID and Status in ('Ready', 'Running', 'Stopped'))
			throw 50000, 'Only a Ready, Running or Stopped batch can be stopped.', 1;
		exec z.usp_TaskQueueSetAction @Action = N'Stop', @ActionID = @ActionID;
		update z.TaskQueueBatch set Status = 'Stopped', FinishedAtUTC = null where BatchID = @BatchID and Status <> 'Stopped';
		commit;
		exec z.usp_TaskQueueSetAction;
	end try
	begin catch
		if @@trancount > 0 rollback;
		exec z.usp_TaskQueueSetAction;
		throw;
	end catch;
end;
