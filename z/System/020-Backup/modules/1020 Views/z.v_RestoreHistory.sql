/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/020-Backup/modules/1020%20Views/z.v_RestoreHistory.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/020-Backup/docs/reference/backup-restore-history.md#zv_restorehistory

Reports one row per recorded restore operation, retaining rows without backup metadata.
*/
create or alter view z.v_RestoreHistory
as
select r.destination_database_name DestinationDatabaseName,
	b.DatabaseName SourceDatabaseName,
	case r.restore_type
		when 'D' then 'Database'
		when 'I' then 'Differential'
		when 'L' then 'Transaction Log'
		when 'F' then 'File'
		when 'G' then 'Filegroup'
		when 'V' then 'Verify Only'
		else 'Other'
	end RestoreType,
	r.restore_date RestoreStartDate,
	b.BackupType,
	b.BackupStartDate,
	b.BackupFinishDate,
	b.Duration BackupDuration,
	b.MediaPaths,
	r.recovery RestoreWithRecovery,
	r.[replace] RestoreWithReplace,
	r.stop_at StopAt,
	r.stop_at_mark_name StopAtMarkName,
	r.stop_before StopBefore,
	b.IsCopyOnly,
	b.FirstLSN,
	b.LastLSN,
	b.CheckpointLSN,
	b.DatabaseBackupLSN,
	b.DifferentialBaseLSN,
	b.ForkPointLSN,
	b.ServerName SourceServerName,
	r.restart RestoreWithRestart,
	r.restore_type RestoreTypeCode,
	b.BackupTypeCode,
	b.MediaFamilyCount,
	r.user_name RestoreLoginName,
	r.restore_history_id RestoreHistoryID,
	r.backup_set_id BackupSetID,
	b.BackupSetGUID,
	b.DatabaseGUID,
	b.FamilyGUID,
	b.FirstRecoveryForkGUID,
	b.LastRecoveryForkGUID,
	b.DifferentialBaseGUID
from msdb.dbo.restorehistory r
	left join z.v_BackupHistory b on b.BackupSetID = r.backup_set_id;
