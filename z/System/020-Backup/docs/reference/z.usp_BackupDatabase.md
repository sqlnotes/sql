# z.usp_BackupDatabase

[Backup](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_BackupDatabase.sql)

## Behavior and parameters

Backs up the selected databases on the current SQL Server instance sequentially (`@Threads = 1`, from smallest to largest data-file size) or concurrently (`@Threads > 1`, from largest to smallest data-file size via temporary SQL Server Agent workers). Choose a full, differential or log backup and a local folder, network share or supported storage URL. By default (`@RetentionHours = null`), it does not delete older files; specify `@RetentionHours` to clean up expired filesystem backups of the requested `@BackupType` after each database's backup completes.

Independent calls to this procedure do not share work. Each database attempt is logged in [z.BackupRestoreHistory](backup-restore-history.md#zbackuprestorehistory); if a database fails, the procedure records the failure, continues processing the remaining databases, and raises a summary error at the end of the call.

The main choices are `@Databases` for what to back up, `@BackupType` for the kind of backup, `@BackupFolder` for the destination, and `@Threads` for worker concurrency. Compression is enabled by default. The complete declaration below includes naming, retention, and native-option overrides.

```text
@Databases nvarchar(max) = 'AllDatabases',
@BackupType nvarchar(50) = 'Full',
@BackupFolder nvarchar(4000) = null,
@BackupCompression bit = 1,
@OtherBackupOptions nvarchar(max) = null,
@ServerName sysname = null,
@BackupFileNameFormat nvarchar(4000) = N'{ServerName}${InstanceName}${DatabaseName}_{yyyyMMdd}_{HHmmssfffffff}',
@FullBackupIfNeeded bit = 1,
@CopyOnly bit = 0,
@CreateServerInstanceFolder bit = 1,
@CreateBackupTypeFolder bit = 1,
@RetentionHours int = null,
@Threads int = 1
```

`@Databases` accepts the group keywords `AllDatabases`, `UserDatabases` and
`SystemDatabases`, a comma-separated list with spaces trimmed around each name,
or a JSON array of literal names such as `N'["Region,West","Reporting"]'`.
A valid JSON array is read as an array and only its string elements are used.
Array names retain leading and trailing spaces. Selection excludes tempdb and
error/recovery states and skips SIMPLE recovery for LOG.

When upgrading a call that used the former exact-name argument, pass the name
as a one-element JSON array in `@Databases` and remove the old argument.
Review positional calls too and prefer named parameters, because `@CopyOnly`, `@CreateServerInstanceFolder`, `@CreateBackupTypeFolder`, `@RetentionHours` and `@Threads` occupy positions 9 through 13.

Set `@CopyOnly = 1` to include `COPY_ONLY` for disk and URL backups. SQL Server
applies it to FULL and LOG and ignores it for DIFFERENTIAL. Read-only databases
include `COPY_ONLY` automatically. Compression NULL uses the server default.
OtherBackupOptions supplies trusted SQL options, including an existing credential
option where appropriate.

ServerName is a destination naming label, not a remote SQL connection. NULL uses @@servername; otherwise the supplied name replaces it in the server/instance prefix. A name without an instance uses MSSQLSERVER; a backslash separates a named instance. The procedure always backs up databases on the instance where it executes.

## Full backup when needed

By default, `@FullBackupIfNeeded = 1` allows the procedure to take a regular full
backup when a selected database lacks the prerequisite for a DIFF or LOG backup.

- DIFF with no primary data-file differential base performs FULL instead of DIFF.
- LOG with an uninitialized log backup chain completes FULL, then performs LOG.
- Existing differential bases and initialized log chains keep the requested type.
  FULL requests and the existing SIMPLE-recovery LOG skip are unchanged.
- Pass `0` or `NULL` to disable the fallback.

Detection uses the target database's sys.database_files primary-file
differential_base_lsn/differential_base_guid and
sys.database_recovery_status.last_log_backup_lsn. A newly added secondary data
file without a base does not trigger a full database backup. These checks inspect
current engine state, not backup history or the existence or usability of media.

Each backup uses its actual type for its folder, extension and BackupType filename
token. A prerequisite full uses the same destination, compression and additional
options. Errors record a failed row in `z.BackupRestoreHistory`, skip any follow-up step for that database, continue to remaining selected databases, and raise a summary error at the end; LOG is attempted only after a successful full and
a confirmed initialized log chain.

A prerequisite full must establish a new differential base. If fallback is needed,
a read-only database or `@CopyOnly = 1` causes an error before the backup runs.
A regular full changes the differential base used
by subsequent differential backups.

```sql
-- Take a prerequisite full backup if the log chain needs initialization.
exec z.usp_BackupDatabase @Databases = N'Sales', @BackupType = N'Log';

-- Request only a differential backup.
exec z.usp_BackupDatabase @Databases = N'Sales', @BackupType = N'Diff',
    @FullBackupIfNeeded = 0;
```

## Additional backup options

Top-level procedure-managed clauses (`COMPRESSION`, `NO_COMPRESSION`, `DIFFERENTIAL`
and `COPY_ONLY`) are stripped from OtherBackupOptions so `BackupCompression`,
`BackupType` and `CopyOnly` remain authoritative. Remaining top-level clauses
(including other duplicates and unknown options) are appended verbatim after the
generated options. NULL or whitespace (or stripping every supplied clause) omits extras.
SQL Server decides option validity when BACKUP executes. Use `BackupCompression`
and `CopyOnly` rather than specifying managed options in `OtherBackupOptions`.

## Filesystem destinations

A NULL BackupFolder uses InstanceDefaultBackupPath. The folder is trimmed; Windows non-URL paths normalize `/` to `\`, including `//server/share` UNC paths. Linux keeps `/`. Paths are not prevalidated; native directory creation and BACKUP determine usability. Missing directories are created before `BACKUP TO DISK`. Directory creation
allows up to three attempts, separated by 1 second, when concurrent
backups race on shared parent folders. Existing directories are accepted; a
persistent creation failure still stops that backup.

By default (`@CreateServerInstanceFolder = 1` and `@CreateBackupTypeFolder = 1`), folders use `<root>/<server>/<instance>/<database>/<type>/`. Each database always keeps its own `<database>` folder:

- Set `@CreateServerInstanceFolder = 0` to omit `<server>/<instance>/` and write under `<root>/<database>/...`.
- Set `@CreateBackupTypeFolder = 0` to omit the `FULL`, `DIFF` and `LOG` subfolders and place all backup types directly inside `<database>/`.
- Passing `NULL` for either folder flag uses the default `1`.

```sql
-- Flat per-database folder for log shipping: <BackupFolder>\<Database>\*.bak, *.diff, *.trn
exec z.usp_BackupDatabase
	@Databases = N'UserDatabases',
	@BackupType = N'Log',
	@BackupFolder = N'\\Share\LogShipping',
	@CreateServerInstanceFolder = 0,
	@CreateBackupTypeFolder = 0;
```

Default filenames are:

```text
Server$MSSQLSERVER$Database_yyyyMMdd_HHmmssfffffff.bak
Server$NamedInstance$Database_yyyyMMdd_HHmmssfffffff.trn
```

Server, instance and database components use `$` separators. The default instance
is included as MSSQLSERVER. The extension is appended automatically: `.bak`
(`.copyonly.bak` for copy-only `FULL`), `.diff`, or `.trn` (`.copyonly.trn` for
copy-only `LOG`). Timestamp tokens use one UTC datetime2(7) value;
`fffffff` writes seven fractional-second digits. Clock accuracy and uniqueness
are not implied by the number of digits. See [date/time formatting](https://learn.microsoft.com/en-us/dotnet/standard/base-types/custom-date-and-time-format-strings).

BackupFileNameFormat supplies the filename without its extension. Supported
replacement tokens are `{ServerName}`, `{InstanceName}`, `{DatabaseName}`,
`{BackupType}`, `{yyyyMMdd}`, `{HHmmssfffffff}`, `{HHmmssffffff}`, `{HHmmss}`,
`{fffffff}` and `{ffffff}`.
All tokens are optional. Other brace text, such as `{daatabase}`, is literal.

For example:

```sql
-- Omit the instance explicitly.
exec z.usp_BackupDatabase @Databases = N'Sales',
    @BackupFileNameFormat = N'{ServerName}${DatabaseName}_{yyyyMMdd}_{HHmmssfffffff}';

-- Use the former database-only, six-digit convention.
exec z.usp_BackupDatabase @Databases = N'Sales',
    @BackupFileNameFormat = N'{DatabaseName}_{yyyyMMdd}_{HHmmss}_{ffffff}';
```

[z.fn_StandardizeFileName](../../../docs/reference/functions.md#zfn_standardizefilename)
standardizes the path components and the rendered filename before the backup
extension is added. SQL Server and the destination determine accepted path and
filename lengths.
Custom layouts outside [recognized filename shapes](z.fn_DecodeBackupFileName.md)
use broader restore header discovery and require header-based cleanup.

## Azure and S3 destinations

Supply a container/bucket URL with an optional object prefix as BackupFolder, not a complete backup filename. `https://` selects Azure Blob URL handling; `s3://` selects S3-compatible storage. The procedure appends the same `<server>/<instance>/<database>/<type>/<file>` prefix layout (controlled by `@CreateServerInstanceFolder` and `@CreateBackupTypeFolder`) using `/`, preserving the URL and object-prefix case. These prefixes do not require directory creation. URL destinations never call filesystem enumeration, directory creation or cleanup.

Use preconfigured SQL Server credentials and storage permissions. Azure block-blob backups on Linux require SAS credentials. S3-compatible backup requires SQL Server 2022 or later; its `s3://` scheme uses HTTPS underneath. The procedure does not create storage accounts, containers, buckets or credentials. See [Azure requirements](https://learn.microsoft.com/en-us/sql/relational-databases/backup-restore/sql-server-backup-to-url) and [S3 requirements](https://learn.microsoft.com/en-us/sql/relational-databases/backup-restore/sql-server-backup-to-url-s3-compatible-object-storage).

## Execution and concurrency

Call with `IMPLICIT_TRANSACTIONS OFF` and no active transaction. Transaction validation runs with `XACT_ABORT ON`. Independent calls do not share assignments. Filesystem backups need SQL Server service-account destination access. Sequential calls require no application-lock or extended-property write permissions.

When `@Threads` is `1` (or `NULL`), or when zero or one database matches `@Databases`, `z.usp_BackupDatabase` executes inline in the caller session (ordered from smallest to largest data-file size) without touching `CONTEXT_INFO` or SQL Server Agent. `@Threads <= 0` throws error `50000`.

When `@Threads > 1` with multiple target databases:

- **Prerequisites and permissions**: SQL Server Agent must be running and visible to the caller (`z.fn_IsSQLAgentRunning`), the caller needs permission to create/drop procedures in schema `z` and manage temporary Agent jobs via `010-Jobs`, the current database name must leave room for 128-character temporary job names (`z_(<db>)_BackupDatabase_<RunID>_<Thread>`), and worker job sessions need visibility into the parent request's `CONTEXT_INFO` in `sys.dm_exec_requests` (`VIEW SERVER STATE` on SQL Server 2019 or `VIEW SERVER PERFORMANCE STATE` on SQL Server 2022+; satisfied automatically when a `sysadmin` caller creates `sa`-owned jobs via default `@SetJobOwnerToSA = 1` in `z.usp_CreateServiceJob`).
- **Worker orchestration**: The procedure sets a run-specific `CONTEXT_INFO` token (`z.BackupDatabase:<RunID>`) on the parent request (restoring the caller's original `CONTEXT_INFO` before returning), creates one temporary executor procedure (`z.usp_BackupDatabaseExecutor_<RunID>`) and one self-dropping per-database procedure (`z.usp_BackupDatabaseWorker_<RunID>_<NNNNN>`, ordered from largest to smallest data-file size) in schema `z`, and starts `min(@Threads, database count)` temporary self-deleting Agent jobs calling the executor procedure. The executor uses [z.usp_ExecuteProcedures](../../../docs/reference/procedures.md#zusp_executeprocedures) to claim and execute remaining per-database procedures one by one without duplicate execution. Each per-database procedure verifies the target database's `database_id`, `name`, `create_date`, and `ONLINE` state, shares the parent run `BatchID` via `SESSION_CONTEXT` when invoking `z.usp_BackupDatabase @Threads = 1` for that single database, swallows errors (recording a fallback `Failed` row in `z.BackupRestoreHistory` if the inner call failed before logging), and drops itself unconditionally.
- **Job startup retries**: The parent polls tracked jobs every second and allows up to three start attempts per job, at least 10 seconds apart. A job that never starts is removed while remaining started workers continue draining the queue; if zero worker jobs start, temporary jobs and procedures are cleaned up and error `50000` is raised.
- **Parent cancellation and stopped/undeleted worker jobs**: If the parent request is cancelled or its job is stopped, its `CONTEXT_INFO` marker disappears from `sys.dm_exec_requests`, causing queued per-database procedures to skip their backups and drop themselves while in-flight backups finish and self-delete their jobs. If all remaining tracked worker jobs have started and none are running (`z.fn_IsSQLJobRunning(JobID) = 1` is false for every remaining tracked job) across 5 consecutive 1-second checks (for example, if a worker job was stopped manually and not auto-deleted by Agent), the parent deletes those leftover jobs, drops remaining executor and worker procedures, and raises error `50000`.
- **Completion and leftover cleanup**: On normal completion, the parent drops the executor procedure (and any unexecuted worker procedures), inspects `z.BackupRestoreHistory` under the shared `BatchID`, and throws summary error `50000` if any database failed or any worker procedure did not complete. If the parent connection is terminated unexpectedly before cleanup runs, run [z.usp_CleanupBackupRestoreObjects](z.usp_CleanupBackupRestoreObjects.md).

## Retention

Retention defaults to disabled (`@RetentionHours = null`). When `@RetentionHours` is set to a positive integer on a filesystem destination (`@IsUrl = 0`), the procedure calls [z.usp_CleanupDatabaseBackups](z.usp_CleanupDatabaseBackups.md) on that database's backup folder after its backup finishes, passing `@BackupType = @BackupType`, `@KeepLatestChain = 1` and `@UseBackupHeader = 0` so expired files of that backup type are removed best-effort while preserving the latest recovery chain: if an active `DIFF` exists for the latest regular `.bak` full, it retains that `.bak`, the latest `DIFF`, 1 predecessor log immediately before that `DIFF`, and subsequent logs (letting expired `.copyonly.bak` files age out); otherwise it retains the newest full (`.bak` or `.copyonly.bak`), 1 predecessor log immediately before that full, and subsequent logs. Zero or negative `@RetentionHours` values are rejected. Although cleanup issues never abort `z.usp_BackupDatabase` or mark `z.BackupRestoreHistory` failed, a locked expired file causes `master.sys.xp_delete_files` to emit error `22049` on the client stream; schedule standalone cleanup separately if concurrent readers lock expired files and a client-side `22049` message would fail the backup job step. For URL destinations, `@RetentionHours` is ignored—use storage lifecycle rules or provider tooling for cloud retention. You can also run `z.usp_CleanupDatabaseBackups` independently against any single-database or multi-database backup folder for custom retention schedules or `@KeepLatestChain = 0` / `@UseBackupHeader = 1` policies.
