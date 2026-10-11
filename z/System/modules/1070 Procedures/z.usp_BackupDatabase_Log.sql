create or alter procedure z.usp_BackupDatabase_Log
as
begin
	exec z.usp_BackupDatabase	@Databases = 'AllDatabases', @BackupType = 'Log', 
								@BackupFolder = '\\Share\backup\MSSQL\', 
								@BackupCompression = 1, @RetentionHours = 50, @OtherBackupOptions = null
end
GO

