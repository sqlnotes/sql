# z.usp_BackupDatabasesParallel

[Backup](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_BackupDatabasesParallel.sql)

Backs up several selected databases concurrently and waits until the workers finish. `@MaxConcurrentWorkers` controls how many backups can run at once. Each selected database is attempted once, and a failure does not prevent the others from being attempted. The call reports failures after the work finishes.

It uses TaskQueue to record each database's result and SQL Server Agent to run the backups. Install TaskQueue and Jobs in the same coordination database, ensure Agent is running and visible, and use an account with the required Agent, metadata and backup permissions. Call outside a transaction with implicit transactions off.

```sql
declare @BatchID bigint;
exec z.usp_BackupDatabasesParallel
    @Databases = N'UserDatabases', @BackupType = N'Full',
    @BackupFolder = N'D:\Backups', @MaxConcurrentWorkers = 3,
    @BatchID = @BatchID output;
```

This example allows up to three backup workers and waits for them to finish. On a successful return, `@BatchID` identifies the retained TaskQueue batch so you can inspect its database-level results later. No summary result set is returned.

Accepts the same Databases, BackupType, BackupFolder, BackupCompression,
OtherBackupOptions, ServerName and BackupFileNameFormat parameters/defaults as
[z.usp_BackupDatabase](z.usp_BackupDatabase.md), followed by
`@MaxConcurrentWorkers int = 3`, `@BatchID bigint = NULL OUTPUT` and
`@CopyOnly bit = 0`. The wrapper forwards CopyOnly to the sequential backup.
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

## Worker execution and cleanup

Workers call the installed sequential backup procedure with the selected database and captured backup options. Each selected database gets a global temporary executor procedure with the TaskQueue signature, `@Parameters nvarchar(max)`.
Names use `##backup_<databaseName>_<uuid>`, with the database-name segment
limited to nvarchar(86) so the full name fits nvarchar(128). Names retain spaces,
punctuation and Unicode; task commands use bracket-delimited identifiers via
QUOTENAME, including escaped closing brackets. Each task passes `N'{}'` as its payload. The wrapper ignores that argument. Database identity and backup options are embedded as
escaped literals in the wrapper, which invokes the installed sequential backup
procedure. NULL values remain NULL and long option strings are preserved.
The wrapper checks the captured database ID, name, creation date and online state
before passing the captured name as a one-element JSON array in `@Databases`.
This keeps a name containing a comma or spaces as a single target.
Workers use the sequential procedure's default `@FullBackupIfNeeded = 1`.
A missing differential base makes the worker take a full backup instead of a
differential. For an uninitialized log chain, it takes a full backup before the
log backup. The sequential procedure skips log backups for SIMPLE databases.

Let active parallel batches finish before upgrading both backup procedures.
The caller remains connected until the workers finish. ExecuteBatch manages only
the batch execution lifecycle. The backup procedure then requires a Completed
batch and successful tasks before removing its wrappers; it throws a retained
task error or a backup-specific explanation otherwise. An empty selection returns
without a result set, batch or jobs. No summary result set is returned; BatchID is
an OUTPUT parameter. SQL Server OUTPUT values are not reliable after THROW; use
the retained TaskQueue rows to investigate failures.

On success, jobs and run-specific procedures are removed; batch/task rows and
audit history remain. No retention cleanup is performed. On error, the backup
procedure rolls back an open transaction and rethrows; it does not explicitly
drop wrappers, which follow global temporary procedure lifetime.
Keep the creating connection alive; cancellation/disconnection may bypass cleanup.
Temporary task commands must be rebuilt before replaying a retained batch.
Appropriately privileged readers can inspect wrapper definitions and task rows. Keep credentials out of literal backup options. Backups run with the job owner's context.
