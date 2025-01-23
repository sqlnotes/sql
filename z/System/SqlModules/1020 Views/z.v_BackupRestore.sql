create or alter view z.v_BackupRestore
as
select	bs.backup_set_id BackupSetID,
		bs.machine_name ServerName,
		bs.database_name DatabaseName,
		case
			when bs.type = 'D' and bs.is_copy_only = 0 then 'Full Database'
			when bs.type = 'D' and bs.is_copy_only = 1 then 'Full Copy-Only Database'
			when bs.type = 'I' then 'Differential Database Backup'
			when bs.type = 'L' then 'Transaction Log'
			when bs.type = 'F' then 'File or Filegroup'
			when bs.type = 'G' then 'Differential File'
			when bs.type = 'P' then 'Partial'
			when bs.type = 'Q' then 'Differential Partial'
		end BackupType,
		case bf.device_type
			when 2 then 'Disk'
			when 5 then 'Tape'
			when 7 then 'Virtual device'
			when 9 then 'Azure Storage'
			when 105 then 'A permanent backup device'
			else 'Other Device'
		end DeviceType,
		bms.software_name BackupSoftware,
		bs.recovery_model RecoveryModel,
		bs.compatibility_level CompatibilityLevel,
		bs.collation_name CollationName,
		bs.Backup_Start_Date BackupStartDate,
		bs.Backup_Finish_Date BackupFinishDate,
		datediff(second, bs.Backup_Start_Date, bs.Backup_Finish_Date) DurationInSec,
		bf.physical_device_name LatestBackupLocation,
		convert(decimal(10, 2), bs.backup_size/1024./1024.) BackupSizeMB,
		convert(decimal(10, 2), bs.compressed_backup_size/1024./1024.) CompressedBackupSizeMB,
		bs.database_backup_lsn DatabaseBackupLSN,
		bs.checkpoint_lsn CheckPointLSN,
		bs.first_lsn FirstLNS,
		bs.last_lsn LastLNS,
		bms.is_password_protected IsPasswordProtected, 
		rh.restore_date RestoreDate,
		rh.destination_database_name RestoredDatabaseName,
		case rh.restore_type
			when 'D' then 'Database'
			when 'F' then 'File'
			when 'G' then 'Filegroup'
			when 'I' then 'Differential'
			when 'L' then 'Log'
			when 'V' then 'Verifyonly'
		end RestoreType,
		rh.replace RestoreWithReplace,
		rh.user_name RestoreLoginName
from msdb.dbo.backupset bs
	left outer join msdb.dbo.backupmediafamily bf ON bs.media_set_id = bf.media_set_id
	inner join msdb.dbo.backupmediaset bms ON bs.media_set_id = bms.media_set_id
	left outer join msdb.dbo.restorehistory rh on rh.backup_set_id = bs.backup_set_id