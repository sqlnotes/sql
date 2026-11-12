/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/baseline/2020%20Tables/z.TaskQueueBatch.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/docs/readme.md

Stores named task batches and their lifecycle timestamps in nonpartitioned storage.
*/
if object_id(N'z.TaskQueueBatch', N'U') is null
begin
	create table z.TaskQueueBatch
	(
		BatchID bigint not null,
		ExecutionID uniqueidentifier not null constraint DF_z_TaskQueueBatch_ExecutionID default (newid()),
		BatchName nvarchar(128) not null,
		BatchType nvarchar(50) not null constraint DF_z_TaskQueueBatch_BatchType default (N'Unclassified'),
		Description nvarchar(max),
		MaxConcurrentWorkers int not null constraint DF_z_TaskQueueBatch_MaxConcurrentWorkers default (0),
		Status varchar(16) not null constraint DF_z_TaskQueueBatch_Status default ('Draft'),
		LastErrorMessage nvarchar(4000),
		CreatedAtUTC datetime2(7) not null constraint DF_z_TaskQueueBatch_CreatedAtUTC default (sysutcdatetime()),
		StartedAtUTC datetime2(7),
		FinishedAtUTC datetime2(7),
		constraint PK_z_TaskQueueBatch primary key clustered (BatchID) with (data_compression = row),
		constraint UQ_z_TaskQueueBatch_BatchName unique (BatchName) with (data_compression = row),
		index IX_z_TaskQueueBatch_Status nonclustered (Status) with (data_compression = row),
		constraint CK_z_TaskQueueBatch_BatchName check (len(trim(BatchName)) > 0),
		constraint CK_z_TaskQueueBatch_MaxConcurrentWorkers check (MaxConcurrentWorkers >= 0),
		constraint CK_z_TaskQueueBatch_Status check (Status in ('Draft', 'Ready', 'Running', 'Completed', 'Stopped'))
	) on [Default];
end;
