/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/modules/1010%20Functions/z.fn_TaskQueueGetBatchSemaphore.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/docs/readme.md#batch-worker-semaphore

Builds the logical worker-capacity semaphore name for one batch.
*/
create or alter function z.fn_TaskQueueGetBatchSemaphore
(
	@BatchID bigint
)
returns nvarchar(200)
as
begin
	return N'z.TaskQueue.Worker:' + convert(nvarchar(20), @BatchID);
end;
