/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/020-Backup/modules/1020%20Views/z.v_BackupHistory.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/020-Backup/docs/reference/backup-restore-history.md#zv_backuphistory

Reports one row per recorded backup set, with media locations and recovery identity.
*/
create or alter view z.v_BackupHistory
as
select b.database_name DatabaseName,
	case b.type
		when 'D' then 'Full Database'
		when 'I' then 'Differential Database'
		when 'L' then 'Transaction Log'
		when 'F' then 'File or Filegroup'
		when 'G' then 'Differential File'
		when 'P' then 'Partial'
		when 'Q' then 'Differential Partial'
		else 'Other'
	end BackupType,
	b.backup_start_date BackupStartDate,
	b.backup_finish_date BackupFinishDate,
	datediff_big(second, b.backup_start_date, b.backup_finish_date) DurationSeconds,
	z.fn_FormatDurationMilliseconds(datediff_big(millisecond, b.backup_start_date, b.backup_finish_date)) Duration,
	convert(decimal(20,2), b.backup_size / 1048576.) BackupSizeMB,
	convert(decimal(20,2), b.compressed_backup_size / 1048576.) CompressedBackupSizeMB,
	m.MediaPaths,
	b.recovery_model RecoveryModel,
	b.is_copy_only IsCopyOnly,
	b.is_damaged IsDamaged,
	b.has_backup_checksums HasBackupChecksums,
	b.has_incomplete_metadata HasIncompleteMetadata,
	b.first_lsn FirstLSN,
	b.last_lsn LastLSN,
	b.checkpoint_lsn CheckpointLSN,
	b.database_backup_lsn DatabaseBackupLSN,
	b.differential_base_lsn DifferentialBaseLSN,
	b.fork_point_lsn ForkPointLSN,
	b.server_name ServerName,
	b.machine_name MachineName,
	b.type BackupTypeCode,
	m.MediaFamilyCount,
	b.user_name BackupLoginName,
	b.backup_set_id BackupSetID,
	b.media_set_id MediaSetID,
	b.backup_set_uuid BackupSetGUID,
	b.database_guid DatabaseGUID,
	b.family_guid FamilyGUID,
	b.first_recovery_fork_guid FirstRecoveryForkGUID,
	b.last_recovery_fork_guid LastRecoveryForkGUID,
	b.differential_base_guid DifferentialBaseGUID
from msdb.dbo.backupset b
	outer apply
	(
		select count_big(*) MediaFamilyCount,
			string_agg(convert(nvarchar(max), f.physical_device_name), nchar(10))
				within group (order by f.mirror, f.family_sequence_number) MediaPaths
		from msdb.dbo.backupmediafamily f where f.media_set_id = b.media_set_id
	) m;
