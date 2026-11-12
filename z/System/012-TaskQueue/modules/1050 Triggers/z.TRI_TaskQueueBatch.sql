/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/modules/1050%20Triggers/z.TRI_TaskQueueBatch.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/docs/readme.md#audit-log

Records committed batch changes with full before/after images and connection context.
*/
create or alter trigger z.TRI_TaskQueueBatch on z.TaskQueueBatch
after insert, update, delete
as
begin
	set nocount, xact_abort on;
	if not exists (select 1 from inserted) and not exists (select 1 from deleted) return;
	declare @Action nvarchar(64) = nullif(try_convert(nvarchar(64), session_context(N'z.TaskQueue.Action')), N''),
		@ActionID uniqueidentifier = coalesce(try_convert(uniqueidentifier, session_context(N'z.TaskQueue.ActionID')), newid());
	insert z.TaskQueueLog
		(BatchID, TaskID, ExecutionID, ActionID, Action, ChangeType,
		 LoginName, ApplicationName, HostName, SessionID, BeforeJson, AfterJson)
		select coalesce(i.BatchID, d.BatchID), null,
			coalesce(i.ExecutionID, d.ExecutionID), @ActionID,
			coalesce(@Action, case when d.BatchID is null then N'DirectInsert' when i.BatchID is null then N'DirectDelete' else N'DirectUpdate' end),
			case when d.BatchID is null then 'Insert' when i.BatchID is null then 'Delete' else 'Update' end,
			original_login(), app_name(), host_name(), @@spid,
			case when d.BatchID is null then null else (select d.BatchID, d.ExecutionID, d.BatchName, d.BatchType, d.Description, d.MaxConcurrentWorkers, d.Status, d.LastErrorMessage, d.CreatedAtUTC, d.StartedAtUTC, d.FinishedAtUTC for json path, include_null_values, without_array_wrapper) end,
			case when i.BatchID is null then null else (select i.BatchID, i.ExecutionID, i.BatchName, i.BatchType, i.Description, i.MaxConcurrentWorkers, i.Status, i.LastErrorMessage, i.CreatedAtUTC, i.StartedAtUTC, i.FinishedAtUTC for json path, include_null_values, without_array_wrapper) end
		from inserted i
			full join deleted d on d.BatchID = i.BatchID;
end;
