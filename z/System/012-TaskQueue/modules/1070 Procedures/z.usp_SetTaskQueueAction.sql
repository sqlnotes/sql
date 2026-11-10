/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/modules/1070%20Procedures/z.usp_SetTaskQueueAction.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/docs/readme.md#audit-log

Sets the audit action and correlation ID. NULL clears the corresponding value;
calling without arguments clears both.
*/
create or alter procedure z.usp_SetTaskQueueAction
(
	@Action nvarchar(64) = null,
	@ActionID uniqueidentifier = null
)
as
begin
	set nocount on;
	exec sys.sp_set_session_context @key = N'z.TaskQueue.Action', @value = @Action;
	exec sys.sp_set_session_context @key = N'z.TaskQueue.ActionID', @value = @ActionID;
end;
