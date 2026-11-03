/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/020-Backup/modules/1070%20Procedures/z.usp_BackupDatabase_Log.sql
*/
create or alter procedure z.usp_BackupDatabase_Log
as
begin
	exec z.usp_BackupDatabase	@Databases = 'AllDatabases', @BackupType = 'Log', 
								@BackupFolder = '\\Share\backup\MSSQL\', 
								@BackupCompression = 1, @OtherBackupOptions = null
end
GO

