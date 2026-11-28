# Backup usage

[Subsystem](readme.md) | [Object reference](reference/readme.md)

Run these calls from the database containing Schema Z. Start with a sequential backup when you want one database backed up at a time; use the parallel example below when several should run concurrently. Each call takes new backups of its selected list.

```sql
exec z.usp_BackupDatabase
	@Databases = N'Application,Reporting',
	@BackupFolder = N'D:/Backup',
	@BackupType = N'FULL',
	@ServerName = N'ProductionLabel';
```

To back up a database named `Region,West`, pass `@Databases = N'["Region,West"]'`.
For a copy-only full or log backup, set `@CopyOnly = 1`. To write directly to `<BackupFolder>\<Database>\` without `<Server>\<Instance>` or `FULL`/`DIFF`/`LOG` subfolders (for example, log shipping), pass `@CreateServerInstanceFolder = 0, @CreateBackupTypeFolder = 0`.

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

The procedure appends server/instance/database/type/timestamped-filename prefixes to these bases (controlled by `@CreateServerInstanceFolder` and `@CreateBackupTypeFolder`). S3 requires SQL Server 2022 or later. URLs use `/` on both operating systems and never create directories or delete old objects. See [destination requirements](reference/z.usp_BackupDatabase.md).

Default filenames include all three components separated by `$`, including
MSSQLSERVER for a default instance. Override BackupFileNameFormat to omit a
component, for example:

```sql
exec z.usp_BackupDatabase @Databases = N'Application',
    @BackupFileNameFormat = N'{ServerName}${DatabaseName}_{yyyyMMdd}_{HHmmssfffffff}';
```

Pass `@RetentionHours` on `z.usp_BackupDatabase` to remove expired filesystem backups of that `@BackupType` automatically while keeping the latest recovery chain, or run [z.usp_CleanupDatabaseBackups](reference/z.usp_CleanupDatabaseBackups.md) directly:

```sql
-- Automatic per-type retention during backup (keeps latest full/diff/log chain even if older than 48 hours):
exec z.usp_BackupDatabase
	@Databases = N'Application',
	@BackupType = N'Log',
	@BackupFolder = N'D:\Backup',
	@RetentionHours = 48;

-- Standalone cleanup across a database folder or entire backup share:
exec z.usp_CleanupDatabaseBackups
	@BackupFolder = N'D:\Backup',
	@RetentionHours = 48,
	@BackupType = 'LOG',
	@KeepLatestChain = 1;
```

Use `@UseBackupHeader = 1` on standalone cleanup calls when backup filenames do not follow the standard convention. URL retention belongs to storage lifecycle policies or separate provider tooling. Inspect [cleanup rules](reference/z.usp_CleanupDatabaseBackups.md) for `@KeepLatestChain` and `@BackupType` behavior. Copy-only `FULL` and `LOG` backups use `.copyonly.bak` and `.copyonly.trn` extensions (including automatic `COPY_ONLY` for read-only databases); SQL Server ignores `COPY_ONLY` for `DIFF` backups.

## Restore a full backup, differential and logs

Preview initialization from a full backup and continuation to the latest compatible
endpoint, preferring logs when they are sufficient:

```sql
exec z.usp_RestoreDatabase
	@BackupPath = N'D:\Backups\ProductionLabel\MSSQLSERVER\Application',
	@TargetDatabaseName = N'Application_Test',
	@DataFolder = N'E:\Data',
	@LogFolder = N'F:\Log',
	@ShowPlan = 1;
```

Set ShowPlan = 0 to execute the selected sequence. The default leaves the database
in NORECOVERY. A missing explicit target uses the unique full-backed source family
(allowing rename) or, when several full-backed families exist in a multi-database
folder, the unique family matching `@TargetDatabaseName`. Several fulls of one
database count once, and unrelated standalone logs/differentials do not add
initialization candidates. Two full-backed families remain ambiguous when neither
matches `@TargetDatabaseName`.
An existing compatible RESTORING/STANDBY target selects its native family and
receives pending backups, ignoring unrelated sources and newer full backups. Explicit replacement of
other existing destinations requires ReplaceExisting = 1, the default.

Omit TargetDatabaseName to process each user database under its source name.
Missing databases with a usable full are initialized; sources without a full are
deferred. Existing ONLINE/unavailable databases are skipped in automatic mode,
including when ReplaceExisting = 1. System databases are excluded. Mixed folders
and files containing appended backup sets use the same selection rules; remote
URLs still identify one object. Recognized filenames group and order discovery;
headers are read backward only as needed. Nonconforming files are inspected next.
Every target plan is completed before the first restore executes.

Log-only planning has priority when it reaches the latest eligible endpoint.
Otherwise a compatible differential can bridge a gap or advance farther, but it
requires its matching full base and cannot follow restored logs. An unbridgeable
gap fails that database's planning without executing a partial chain. Independent
databases continue, and outcomes retain individual failures.
Use RecoveryType = 'RECOVERY' to bring the result online, or 'STANDBY' for read
access between restores. Recurring shipping requires NORECOVERY or STANDBY.
A null StandbyFolder places the standardized target name with extension .standby
beside the primary data file.
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

Pass `@Threads > 1` on `z.usp_BackupDatabase` to back up multiple databases concurrently through temporary SQL Server Agent worker jobs (`@Threads = 1` or single-database selections run inline):

```sql
exec z.usp_BackupDatabase
	@Databases = N'UserDatabases',
	@BackupType = N'Full',
	@BackupFolder = N'D:\Backups',
	@Threads = 3;
```

The parent procedure creates one executor procedure and one self-dropping per-database procedure per selected database (queued largest-first), launches up to `@Threads` temporary Agent jobs (capped at the selected database count), waits until every job finishes, drops the executor procedure, and raises summary error `50000` if any database failed or remained incomplete. All database outcomes share one `BatchID` in `z.BackupRestoreHistory`. If the parent request is cancelled, remaining queued procedures skip their backups and drop themselves; if all remaining started worker jobs stop running without Agent auto-deleting them across 5 consecutive 1-second checks, the parent removes those leftover jobs and temporary procedures and raises error `50000`. If the parent session is terminated unexpectedly before cleanup runs, call [z.usp_CleanupBackupRestoreObjects](reference/z.usp_CleanupBackupRestoreObjects.md) on demand to remove leftover procedures and idle temporary jobs.

See [z.usp_BackupDatabase reference](reference/z.usp_BackupDatabase.md).
