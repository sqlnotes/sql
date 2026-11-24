# z.usp_BackupDatabase

[Backup](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_BackupDatabase.sql)

## Behavior and parameters

Backs up the selected databases on the current SQL Server instance, one at a time, from smallest to largest data-file size. Choose a full, differential or log backup and a local folder, network share or supported storage URL. Each call takes a new set of backups; it does not delete older files.

Use [parallel backup](z.usp_BackupDatabasesParallel.md) when several databases should back up concurrently. Independent calls to this procedure do not share work. If a backup fails, the call stops and earlier successful backups remain.

The main choices are `@Databases` for what to back up, `@BackupType` for the kind of backup, and `@BackupFolder` for the destination. Compression is enabled by default. The complete declaration below includes naming and native-option overrides.

```text
@Databases nvarchar(max) = 'AllDatabases',
@BackupType nvarchar(50) = 'Full',
@BackupFolder nvarchar(4000) = null,
@BackupCompression bit = 1,
@OtherBackupOptions nvarchar(max) = null,
@ServerName sysname = null,
@BackupFileNameFormat nvarchar(4000) = N'{ServerName}${InstanceName}${DatabaseName}_{yyyyMMdd}_{HHmmssfffffff}',
@FullBackupIfNeeded bit = 1,
@CopyOnly bit = 0
```

`@Databases` accepts the group keywords `AllDatabases`, `UserDatabases` and
`SystemDatabases`, a comma-separated list with spaces trimmed around each name,
or a JSON array of literal names such as `N'["Region,West","Reporting"]'`.
A valid JSON array is read as an array and only its string elements are used.
Array names retain leading and trailing spaces. Selection excludes tempdb and
error/recovery states and skips SIMPLE recovery for LOG.

When upgrading a call that used the former exact-name argument, pass the name
as a one-element JSON array in `@Databases` and remove the old argument.
Review positional calls too because `@CopyOnly` now occupies the ninth slot.

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
options. Errors stop the call; LOG is attempted only after a successful full and
a confirmed initialized log chain.

A prerequisite full must establish a new differential base. If fallback is needed,
a read-only database or `@CopyOnly = 1` causes an error before the backup runs.
A `COPY_ONLY` supplied through OtherBackupOptions can produce a copy-only file
before the base check fails. A regular full changes the differential base used
by subsequent differential backups.

```sql
-- Take a prerequisite full backup if the log chain needs initialization.
exec z.usp_BackupDatabase @Databases = N'Sales', @BackupType = N'Log';

-- Request only a differential backup.
exec z.usp_BackupDatabase @Databases = N'Sales', @BackupType = N'Diff',
    @FullBackupIfNeeded = 0;
```

## Additional backup options

OtherBackupOptions is appended unchanged after generated compression,
DIFFERENTIAL and COPY_ONLY options. NULL or whitespace omits extras.
The procedure does not parse, validate or deduplicate supplied options. SQL
Server decides option validity when BACKUP executes; duplicate options may be
accepted by the engine and are not normalized by this procedure. Use
BackupCompression to choose compression rather than repeating it in the options.

## Filesystem destinations

A NULL BackupFolder uses InstanceDefaultBackupPath. The folder is trimmed; Windows non-URL paths normalize `/` to `\`, including `//server/share` UNC paths. Linux keeps `/`. Paths are not prevalidated; native directory creation and BACKUP determine usability. Missing directories are created before `BACKUP TO DISK`. Directory creation
allows up to three attempts, separated by 100 milliseconds, when concurrent
backups race on shared parent folders. Existing directories are accepted; a
persistent creation failure still stops that backup.

Folders remain `<root>/<server>/<instance>/<database>/<type>/`. Default filenames are:

```text
Server$MSSQLSERVER$Database_yyyyMMdd_HHmmssfffffff.bak
Server$NamedInstance$Database_yyyyMMdd_HHmmssfffffff.trn
```

Server, instance and database components use `$` separators. The default instance
is included as MSSQLSERVER. The extension is appended automatically: `.bak`,
`.diff` or `.trn`. Timestamp tokens use one UTC datetime2(7) value;
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

Supply a container/bucket URL with an optional object prefix as BackupFolder, not a complete backup filename. `https://` selects Azure Blob URL handling; `s3://` selects S3-compatible storage. The procedure appends the same server/instance/database/type/file naming layout using `/`, preserving the URL and object-prefix case. These prefixes do not require directory creation. URL destinations never call filesystem enumeration, directory creation or cleanup.

Use preconfigured SQL Server credentials and storage permissions. Azure block-blob backups on Linux require SAS credentials. S3-compatible backup requires SQL Server 2022 or later; its `s3://` scheme uses HTTPS underneath. The procedure does not create storage accounts, containers, buckets or credentials. See [Azure requirements](https://learn.microsoft.com/en-us/sql/relational-databases/backup-restore/sql-server-backup-to-url) and [S3 requirements](https://learn.microsoft.com/en-us/sql/relational-databases/backup-restore/sql-server-backup-to-url-s3-compatible-object-storage).

## Execution and retention

Call with `IMPLICIT_TRANSACTIONS OFF` and no active transaction. Transaction
validation runs with `XACT_ABORT ON`. For a bounded pool across selected databases, use
[z.usp_BackupDatabasesParallel](z.usp_BackupDatabasesParallel.md). Independent
sequential calls do not share assignments. Filesystem backups need SQL Server service-account destination access. The main procedure requires no application-lock or extended-property write permissions.

Retention is separate. The removed RetentionHours and UseBackupHeaderToDetermineBackupDate parameters are no longer accepted. The sixth positional argument is now ServerName, so update positional callers as well as named retention arguments. Schedule [filesystem cleanup](z.usp_CleanupDatabaseBackups.md) separately from active backups; use storage lifecycle rules or separate provider tooling for URL retention. The backup procedure never deletes old backups.
