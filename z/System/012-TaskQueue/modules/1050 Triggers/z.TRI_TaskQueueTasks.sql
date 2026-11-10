/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/modules/1050%20Triggers/z.TRI_TaskQueueTasks.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/docs/readme.md#audit-log

Records committed task changes with full before/after images and connection context.
*/
create or alter trigger z.TRI_TaskQueueTasks on z.TaskQueueTasks
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
		select coalesce(i.BatchID, d.BatchID), coalesce(i.TaskID, d.TaskID),
			b.ExecutionID, @ActionID,
			coalesce(@Action, case when d.BatchID is null then N'DirectInsert' when i.BatchID is null then N'DirectDelete' else N'DirectUpdate' end),
			case when d.BatchID is null then 'Insert' when i.BatchID is null then 'Delete' else 'Update' end,
			original_login(), app_name(), host_name(), @@spid,
			case when d.BatchID is null then null else (select d.BatchID, d.TaskID, d.TaskName, d.Description, d.TaskBody, d.SortOrder, d.CompletionCondition, d.Status, d.MaxRetries, d.RetryIntervalSecond, d.AttemptsStarted, d.AvailableAtUTC, d.ClaimToken, d.WorkerSessionID, d.WorkerLoginTime, d.CreatedAtUTC, d.StartedAtUTC, d.FinishedAtUTC, d.LastErrorNumber, d.LastErrorMessage for json path, include_null_values, without_array_wrapper) end,
			case when i.BatchID is null then null else (select i.BatchID, i.TaskID, i.TaskName, i.Description, i.TaskBody, i.SortOrder, i.CompletionCondition, i.Status, i.MaxRetries, i.RetryIntervalSecond, i.AttemptsStarted, i.AvailableAtUTC, i.ClaimToken, i.WorkerSessionID, i.WorkerLoginTime, i.CreatedAtUTC, i.StartedAtUTC, i.FinishedAtUTC, i.LastErrorNumber, i.LastErrorMessage for json path, include_null_values, without_array_wrapper) end
		from inserted i
			full join deleted d on d.BatchID = i.BatchID and d.TaskID = i.TaskID
			join z.TaskQueueBatch b on b.BatchID = coalesce(i.BatchID, d.BatchID);
end;
