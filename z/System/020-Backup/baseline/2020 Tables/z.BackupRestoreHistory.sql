/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/020-Backup/baseline/2020%20Tables/z.BackupRestoreHistory.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/020-Backup/docs/reference/backup-restore-history.md#zbackuprestorehistory

Stores partition-managed backup and restore execution history with row compression.
*/
if object_id(N'z.BackupRestoreHistory', N'U') is null
begin
	create table z.BackupRestoreHistory
	(
		HistoryID bigint not null constraint DF_z_BackupRestoreHistory_HistoryID default (datediff_big(second, '19000101', getutcdate()) * 268435456 | next value for z.SeqGeneralID),
		BatchID uniqueidentifier not null,
		Operation varchar(10) not null,
		DatabaseName nvarchar(128),
		SourceDatabaseName nvarchar(128),
		BackupType varchar(10),
		RecoveryType varchar(10),
		IsCopyOnly bit,
		BackupFile nvarchar(1024),
		StartTime datetime2(3) not null,
		EndTime datetime2(3) not null,
		DurationMs bigint not null,
		Status varchar(20) not null,
		ErrorNumber int,
		ErrorMessage nvarchar(512),
		LoginName nvarchar(128) not null constraint DF_z_BackupRestoreHistory_LoginName default (original_login()),
		ApplicationName nvarchar(128) constraint DF_z_BackupRestoreHistory_ApplicationName default (app_name()),
		HostName nvarchar(128) constraint DF_z_BackupRestoreHistory_HostName default (host_name()),
		SessionID smallint not null constraint DF_z_BackupRestoreHistory_SessionID default (@@spid),
		constraint PK_z_BackupRestoreHistory primary key clustered (HistoryID) with (data_compression = row) on PS_SchemaZPartitionGeneric(HistoryID),
		constraint CK_z_BackupRestoreHistory_Operation check (Operation in ('Backup', 'Restore')),
		constraint CK_z_BackupRestoreHistory_Status check (Status in ('Succeeded', 'Failed'))
	) on PS_SchemaZPartitionGeneric(HistoryID);
end;
