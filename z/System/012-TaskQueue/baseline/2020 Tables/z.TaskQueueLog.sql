/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/baseline/2020%20Tables/z.TaskQueueLog.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/docs/readme.md#audit-log

Stores partition-managed committed changes and their action, execution and connection context.
*/
if object_id(N'z.TaskQueueLog', N'U') is null
begin
	create table z.TaskQueueLog
	(
		LogID bigint not null constraint DF_z_TaskQueueLog_LogID default (datediff_big(second, '19000101', getutcdate()) * 268435456 | next value for z.SeqGeneralID),
		BatchID bigint not null,
		TaskID int,
		ExecutionID uniqueidentifier not null,
		ActionID uniqueidentifier not null,
		Action nvarchar(64) not null,
		ChangeType varchar(6) not null,
		LoginName nvarchar(128) not null,
		ApplicationName nvarchar(128),
		HostName nvarchar(128),
		SessionID smallint not null,
		BeforeJson nvarchar(max),
		AfterJson nvarchar(max),
		constraint PK_z_TaskQueueLog primary key clustered (LogID) with (data_compression = page) on PS_SchemaZPartitionGeneric(LogID),
		constraint CK_z_TaskQueueLog_ChangeType check (ChangeType in ('Insert', 'Update', 'Delete')),
		constraint CK_z_TaskQueueLog_BeforeJson check (BeforeJson is null or isjson(BeforeJson) = 1),
		constraint CK_z_TaskQueueLog_AfterJson check (AfterJson is null or isjson(AfterJson) = 1),
		index IX_z_TaskQueueLog_BatchID_ExecutionID_LogID nonclustered (BatchID, ExecutionID, LogID) with (data_compression = page) on PS_SchemaZPartitionGeneric(LogID),
		index IX_z_TaskQueueLog_ActionID_LogID nonclustered (ActionID, LogID) with (data_compression = page) on PS_SchemaZPartitionGeneric(LogID)
	) on PS_SchemaZPartitionGeneric(LogID);
end;
