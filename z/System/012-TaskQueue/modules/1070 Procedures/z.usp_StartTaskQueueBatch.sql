/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/modules/1070%20Procedures/z.usp_StartTaskQueueBatch.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/docs/readme.md#batch-lifecycle

Publishes a Draft batch as Ready without scanning or validating task bodies.
Uses a short transaction and the batch semaphore for atomic mutation.
A successful nested call leaves its caller transaction open; errors roll back the
active transaction. The procedure does not change transaction session settings.
*/
create or alter procedure z.usp_StartTaskQueueBatch
(
	@BatchID bigint = null,
	@BatchName nvarchar(128) = null
)
as
begin
	set nocount on;
	declare @ActionID uniqueidentifier = newid(), @BatchSemaphore nvarchar(200);
	begin try
		begin tran;
		exec z.usp_ResolveTaskQueueBatch @BatchID = @BatchID output, @BatchName = @BatchName;
		select @BatchSemaphore = N'z.TaskQueue.Batch:' + convert(nvarchar(20), @BatchID);
		exec z.usp_AcquireSemaphore @SemaphoreName = @BatchSemaphore, @TotalCount = 1, @LockOwner = 'Transaction';
		exec z.usp_SetTaskQueueAction @Action = N'Start', @ActionID = @ActionID;
		update z.TaskQueueBatch set Status = 'Ready' where BatchID = @BatchID and Status = 'Draft';
		if @@rowcount = 0 throw 50000, 'Only a Draft batch can be started.', 1;
		commit;
		exec z.usp_SetTaskQueueAction;
	end try
	begin catch
		if @@trancount > 0 rollback;
		exec z.usp_SetTaskQueueAction;
		throw;
	end catch;
end;
