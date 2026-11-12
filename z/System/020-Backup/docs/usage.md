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

Default filenames include all three components separated by `$`, including
MSSQLSERVER for a default instance. Override BackupFileNameFormat to omit a
component, for example:

```sql
exec z.usp_BackupDatabase @Databases = N'Application',
    @BackupFileNameFormat = N'{ServerName}${DatabaseName}_{yyyyMMdd}_{HHmmssfffffff}';
```

Schedule filesystem retention independently:

```sql
exec z.usp_CleanupDatabaseBackups
	@DatabaseName = N'Application',
	@DatabaseBackupFolder = N'D:\Backup\ProductionLabel\MSSQLSERVER\Application',
	@RetentionHours = 48,
	@ShowPlan = 1;
```

Use `@UseBackupHeader = 1` on the cleanup procedure for header-based cleanup. URL retention belongs to storage lifecycle policies or separate provider tooling. Inspect [cleanup rules](reference/z.usp_CleanupDatabaseBackups.md) before deletion. Read-only FULL and LOG backups automatically use COPY_ONLY. SQL Server ignores that option for DIFF backups. Request COPY_ONLY explicitly through OtherBackupOptions for read-write backups when needed.

## Restore a full backup, differential and logs

Preview the latest full backup, optional compatible differential and remaining log chain:

```sql
exec z.usp_RestoreDatabase
	@BackupPath = N'D:\Backups\ProductionLabel\MSSQLSERVER\Application',
	@TargetDatabaseName = N'Application_Test',
	@DataFolder = N'E:\Data',
	@LogFolder = N'F:\Log',
	@ShowPlan = 1;
```

Set ShowPlan = 0 to execute the selected sequence. The default leaves the database
in NORECOVERY and permits replacement of an existing destination outside restore
or standby mode. TargetDatabaseName prefers a source with that name; when none matches,
the latest full is used as a rename source. Mixed-source folders are supported.
Managed timestamped filenames reduce the number of headers opened; arbitrary
names use broader header discovery. Review the chosen source in the preview.
A compatible restoring/standby destination receives only pending backups; a
differential requires its matching full base and cannot follow restored logs.
Use RecoveryType = 'RECOVERY' to bring the result online, or
'STANDBY' for read access between restores. A null StandbyFolder places the full
backup's basename with extension .standby beside the primary data file.
See the [restore reference](reference/z.usp_RestoreDatabase.md) for source selection,
path rules, continuation requirements and failure behavior.

Explicit DataFolder/LogFolder values take precedence independently. Unspecified
folders use the instance defaults with UseDefaultFolder = 1 (the default).
Set UseDefaultFolder = 0 to keep the directories recorded in the backup.
Data/log directory existence is left to native RESTORE; preview only shows the
planned mappings. Continuation keeps existing files in their current directories.
If a differential or log introduces new files, folder options apply to those files
only. The introducing restore command gets the MOVE clauses; existing files stay
in place. Renamed destinations replace the source-name portion of each new
basename or prefix the destination name when the source name is absent.

An HTTP(S) or S3 BackupPath must identify one backup object, such as
`s3://storage.example.test/backups/Application.bak`. It is treated as a single
file, without remote folder discovery. A full initializes the destination;
individual differential or log URLs continue a compatible unrecovered destination.
Configure SQL Server storage credentials beforehand. S3 requires SQL Server 2022+;
native endpoint and transport support applies to all URLs.

DropConnections defaults to 1: an existing ONLINE destination is set to SINGLE_USER
WITH ROLLBACK IMMEDIATE before pending restores. Unavailable destinations and
no-op restores skip this step. Set DropConnections = 0 to disable it. Preview shows
access-mode actions without executing them. The prior mode is restored when the
same database remains ONLINE; see the reference for NORECOVERY and failure limits.

OtherRestoreOptions defaults to `stats = 10` on media restore commands. To change
progress reporting or add native options, pass a list such as
`N'stats = 5, checksum, buffercount = 8'`; NULL disables the extra options.
The preview returns the same ordered command table that execution consumes.

## Parallel backups

```sql
exec z.usp_BackupDatabasesParallel @Databases = N'UserDatabases',
    @BackupType = N'Full', @BackupFolder = N'D:\Backups', @MaxConcurrentWorkers = 3;
```

Waits for temporary Agent workers, attempts every selected database once and
throws after completion if any task failed. Inspect retained TaskQueue results.
See [parallel backup reference](reference/z.usp_BackupDatabasesParallel.md).
