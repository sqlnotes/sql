/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/modules/1010%20Functions/z.fn_TaskQueueGetTaskSemaphore.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/docs/readme.md#task-semaphore

Builds the logical task semaphore name used by the shared acquire and release procedures.
*/
create or alter function z.fn_TaskQueueGetTaskSemaphore
(
	@BatchID bigint,
	@TaskID int
)
returns nvarchar(200)
as
begin
	return N'z.TaskQueue.Task:' + convert(nvarchar(20), @BatchID) + N':' + convert(nvarchar(11), @TaskID);
end;
