/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/020-Backup/modules/1070%20Procedures/z.usp_BackupDatabase_Full.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/020-Backup/docs/reference/z.usp_BackupDatabase_Full.md

Runs full backups with the wrapper's predefined destination and options.
*/
create or alter procedure z.usp_BackupDatabase_Full
as
begin
	exec z.usp_BackupDatabase	@Databases = 'AllDatabases', @BackupType = 'FULL', 
								@BackupFolder = '\\Share\backup\MSSQL\', 
								@BackupCompression = 1, @OtherBackupOptions = 'stats = 1'
end
GO

