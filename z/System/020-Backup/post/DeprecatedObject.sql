-- Triggers
exec z.usp_DropObject @ObjectName = N'z.TRI_v_DatabaseBackupStatus';

-- Procedures
exec z.usp_DropObject @ObjectName = N'z.usp_BackupDatabaseWork';
exec z.usp_DropObject @ObjectName = N'z.usp_DatabaseBackup';

-- Views
exec z.usp_DropObject @ObjectName = N'z.v_DatabaseBackupStatus';
