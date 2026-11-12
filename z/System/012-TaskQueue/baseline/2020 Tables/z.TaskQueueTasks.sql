/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/baseline/2020%20Tables/z.TaskQueueTasks.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/docs/readme.md#task-table

Stores JSON task bodies, execution levels, completion conditions and retry state.
*/
set quoted_identifier on;
set ansi_nulls, ansi_padding, ansi_warnings, arithabort, concat_null_yields_null on;
set numeric_roundabort off;

if object_id(N'z.TaskQueueTasks', N'U') is null
begin
	create table z.TaskQueueTasks
	(
		BatchID bigint not null,
		TaskID int not null,
		TaskName nvarchar(128) not null,
		Description nvarchar(max),
		TaskBody nvarchar(max) not null,
		SortOrder bigint not null,
		CompletionCondition varchar(16) not null constraint DF_z_TaskQueueTasks_CompletionCondition default ('Succeeded'),
		Status varchar(16) not null constraint DF_z_TaskQueueTasks_Status default ('Pending'),
		MaxRetries int not null constraint DF_z_TaskQueueTasks_MaxRetries default (0),
		RetryIntervalSecond int not null constraint DF_z_TaskQueueTasks_RetryIntervalSecond default (60),
		AttemptsStarted int not null constraint DF_z_TaskQueueTasks_AttemptsStarted default (0),
		AvailableAtUTC datetime2(7) not null constraint DF_z_TaskQueueTasks_AvailableAtUTC default (sysutcdatetime()),
		ClaimToken uniqueidentifier,
		WorkerSessionID smallint,
		WorkerLoginTime datetime,
		CreatedAtUTC datetime2(7) not null constraint DF_z_TaskQueueTasks_CreatedAtUTC default (sysutcdatetime()),
		StartedAtUTC datetime2(7),
		FinishedAtUTC datetime2(7),
		LastErrorNumber int,
		LastErrorMessage nvarchar(4000),
		CompletionState as convert(tinyint, case
			when Status = 'Blocked' or Status = 'NeedsReview' then 1
			when Status = 'Succeeded' then case when CompletionCondition = 'Failed' then 1 else 2 end
			when Status = 'Failed' and convert(bigint, AttemptsStarted) >= convert(bigint, MaxRetries) + 1 then case when CompletionCondition = 'Succeeded' then 1 else 2 end
			else 0 end),
		constraint PK_z_TaskQueueTasks primary key clustered (BatchID, TaskID) with (data_compression = row),
		constraint FK_z_TaskQueueTasks_Batch foreign key (BatchID) references z.TaskQueueBatch (BatchID),
		constraint CK_z_TaskQueueTasks_TaskName check (len(trim(TaskName)) > 0),
		constraint CK_z_TaskQueueTasks_TaskBody check (isjson(TaskBody) = 1),
		constraint CK_z_TaskQueueTasks_CompletionCondition check (CompletionCondition in ('Succeeded', 'Failed', 'Finished')),
		constraint CK_z_TaskQueueTasks_Status check (Status in ('Pending', 'Running', 'Succeeded', 'Failed', 'Blocked', 'NeedsReview')),
		constraint CK_z_TaskQueueTasks_MaxRetries check (MaxRetries >= 0),
		constraint CK_z_TaskQueueTasks_RetryIntervalSecond check (RetryIntervalSecond >= 0),
		constraint CK_z_TaskQueueTasks_AttemptsStarted check (AttemptsStarted >= 0),
		index IX_z_TaskQueueTasks_BatchID_Status_SortOrder_AvailableAtUTC nonclustered (BatchID, Status, SortOrder, AvailableAtUTC) with (data_compression = row),
		index IX_z_TaskQueueTasks_BatchID_CompletionState_SortOrder_TaskID nonclustered (BatchID, CompletionState, SortOrder, TaskID) include (Status, AvailableAtUTC, AttemptsStarted, MaxRetries, RetryIntervalSecond, CompletionCondition) with (data_compression = row),
		index IX_z_TaskQueueTasks_BatchID_TaskID nonclustered (BatchID, TaskID) where Status = 'Running' with (data_compression = row)
	) on [Default];
end;
