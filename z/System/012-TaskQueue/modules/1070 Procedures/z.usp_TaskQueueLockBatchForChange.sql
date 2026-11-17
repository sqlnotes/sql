/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/modules/1070%20Procedures/z.usp_TaskQueueLockBatchForChange.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/docs/readme.md#batch-change-lock

Locks one batch for changes within the caller's active transaction.
Without an active transaction, returns without acquiring a semaphore.
*/
create or alter procedure z.usp_TaskQueueLockBatchForChange
(
	@BatchID bigint
)
as
begin
	set nocount on;
	if @@trancount = 0 return;
	declare @SemaphoreName nvarchar(200), @Slot int;
	select	@SemaphoreName = N'z.TaskQueue.Batch:' + convert(nvarchar(20), @BatchID);
	exec @Slot = z.usp_AcquireSemaphore @SemaphoreName = @SemaphoreName, @TotalCount = 1, @LockOwner = 'Transaction';
	if @Slot <= 0 throw 50000, 'Cannot acquire the TaskQueue batch change semaphore.', 1;
end;
