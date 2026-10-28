# Backup usage

[Subsystem](readme.md) | [Object reference](reference/readme.md)

Run one invocation at a time from a database containing the Backup subsystem. Each call backs up the selected list again.

```sql
exec z.usp_BackupDatabase
	@Databases = N'Application,Reporting',
	@BackupFolder = N'D:/Backup',
	@BackupType = N'FULL',
	@ServerName = N'ProductionLabel';
```

ServerName controls the destination prefix only. Omit it or pass NULL to use @@servername. It does not connect to another server. Windows accepts slash-separated inputs through normalization; use a mounted filesystem path such as `/mnt/backup` on Linux.

With credentials already configured, use a storage URL base:

```sql
exec z.usp_BackupDatabase
	@Databases = N'Application',
	@BackupFolder = N'https://myaccount.blob.core.windows.net/backups/Production',
	@BackupType = N'FULL';

exec z.usp_BackupDatabase
	@Databases = N'Application',
	@BackupFolder = N's3://mybucket.s3.us-west-2.amazonaws.com/backups',
	@BackupType = N'FULL',
	@ServerName = N'ProductionLabel';
```

The procedure appends server/instance/database/type/timestamped-filename prefixes to these bases. S3 requires SQL Server 2022 or later. URLs use `/` on both operating systems and never create directories or delete old objects. See [destination requirements](reference/z.usp_BackupDatabase.md).

Schedule filesystem retention independently:

```sql
exec z.usp_CleanupDatabaseBackups
	@DatabaseName = N'Application',
	@DatabaseBackupFolder = N'D:\Backup\ProductionLabel\MSSQLSERVER\Application',
	@RetentionHours = 48,
	@ShowPlan = 1;
```

Use `@UseBackupHeader = 1` on the cleanup procedure for header-based cleanup. URL retention belongs to storage lifecycle policies or separate provider tooling. Inspect [cleanup rules](reference/z.usp_CleanupDatabaseBackups.md) before deletion. Read-only FULL and LOG backups automatically use COPY_ONLY. SQL Server ignores that option for DIFF backups. Request COPY_ONLY explicitly through OtherBackupOptions for read-write backups when needed.
