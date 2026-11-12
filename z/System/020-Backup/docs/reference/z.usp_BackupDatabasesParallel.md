# z.usp_BackupDatabasesParallel

[Backup](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_BackupDatabasesParallel.sql)

Creates one task per selected database and waits for bounded SQL Server Agent
workers to finish. Requires TaskQueue and Jobs installed in the same coordination
database, a running visible Agent, and appropriate Agent, metadata and backup
permissions. Call outside a transaction with implicit transactions off.

```sql
declare @BatchID bigint;
exec z.usp_BackupDatabasesParallel
    @Databases = N'UserDatabases', @BackupType = N'Full',
    @BackupFolder = N'D:\Backups', @MaxConcurrentWorkers = 3,
    @BatchID = @BatchID output;
```

Accepts the same Databases, BackupType, BackupFolder, BackupCompression,
OtherBackupOptions, ServerName and BackupFileNameFormat parameters/defaults as
[z.usp_BackupDatabase](z.usp_BackupDatabase.md), followed by
`@MaxConcurrentWorkers int = 3` and `@BatchID bigint = NULL OUTPUT`.
BatchID is an output for the newly generated batch; an input value is cleared.
Batch names use `<@@servername> - <BackupType> - yyyy-MM-dd HH:mm:ss.fffffff`,
using the actual SQL Server name, server local timestamp and normalized FULL,
DIFF or LOG backup type. TaskName is the selected database name.

Database selection is captured once without filtering by recovery model.
The backup procedure decides whether to skip each database.
Tasks are numbered by decreasing database size and share one execution level. Each is attempted
once, with Finished as its completion condition, so one backup error does not
prevent other databases from being attempted. BatchType is Backup. Overlapping
calls are independent and are allowed; external backup operations are not coordinated.

One parameterless global temporary procedure is created per selected database.
Names use `##backup_<databaseName>_<uuid>`, with the database-name segment
limited to nvarchar(86) so the full name fits nvarchar(128). Names retain spaces,
punctuation and Unicode; task commands use bracket-delimited identifiers via
QUOTENAME, including escaped closing brackets. Each task has an
empty parameters array. Database identity and backup options are embedded as
escaped literals in the wrapper, which invokes the installed sequential backup
procedure. NULL values remain NULL and long option strings are preserved.
The wrapper checks the captured database ID, name, creation date and online state
before calling the backup procedure. Recovery-model eligibility is left to the
backup procedure, which skips incompatible databases. Backup selection and execution follow
the existing sequential procedure's behavior.

The caller remains connected until the workers finish. The launcher returns
BatchID, TotalTasks, SucceededTasks and FailedTasks, then throws if any task failed
or the batch stopped. An empty selection returns without a result set, batch or
jobs. SQL Server OUTPUT values are not reliable after THROW; use the summary's BatchID or retained TaskQueue rows to investigate failures.

On success, jobs and run-specific procedures are removed; batch/task rows and
audit history remain. No retention cleanup is performed. On error, the backup
procedure rolls back an open transaction and rethrows; it does not explicitly
drop wrappers, which follow global temporary procedure lifetime.
Keep the creating connection alive; cancellation/disconnection may bypass cleanup.
Temporary task commands must be rebuilt before replaying a retained batch.
Settings and task bodies are visible to appropriately privileged readers; do not
supply secrets as literal backup options. Backups run with the job owner's context.
