/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/modules/1010%20Functions/z.fn_TaskQueueGetTaskSemaphoreSlot.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/docs/readme.md#task-semaphore

Builds the fixed slot-1 application-lock resource for a task semaphore.
*/
create or alter function z.fn_TaskQueueGetTaskSemaphoreSlot
(
	@BatchID bigint,
	@TaskID int
)
returns nvarchar(255)
as
begin
	return N'1-' + z.fn_TaskQueueGetTaskSemaphore(@BatchID, @TaskID);
end;
