create or alter procedure z.usp_BackupDatabase_Full
as
begin
	exec z.usp_BackupDatabase	@Databases = 'AllDatabases', @BackupType = 'FULL', 
								@BackupFolder = '\\Share\backup\MSSQL\', 
								@BackupCompression = 1, @OtherBackupOptions = 'stats = 1'
end
GO

