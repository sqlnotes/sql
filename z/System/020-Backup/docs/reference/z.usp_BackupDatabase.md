# z.usp_BackupDatabase

[Backup](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_BackupDatabase.sql)

## Behavior and parameters

Back up the selected databases sequentially in ascending data-file size. Every invocation processes its selected list again. There is no parallel worker pool, persistent status, application lock or retention operation. Errors propagate and stop remaining work; earlier backups remain.

```text
@Databases nvarchar(max) = 'AllDatabases',
@BackupType nvarchar(50) = 'Full',
@BackupFolder nvarchar(4000) = null,
@BackupCompression bit = 1,
@OtherBackupOptions nvarchar(max) = null,
@ServerName sysname = null,
@BackupFileNameFormat nvarchar(4000) = N'{ServerName}${InstanceName}${DatabaseName}_{yyyyMMdd}_{HHmmssfffffff}'
```

Databases accepts AllDatabases, UserDatabases, SystemDatabases or comma-separated names. Exclude tempdb and error/recovery states; skip SIMPLE recovery for LOG. Read-only databases automatically include COPY_ONLY for disk and URL backups. SQL Server honors it for FULL and LOG; with DIFFERENTIAL it has no effect and the requested type remains DIFF. Read-write backups use COPY_ONLY only when explicitly supplied in OtherBackupOptions. Compression NULL uses the server default. OtherBackupOptions supplies trusted SQL options, including an existing credential option where appropriate.

ServerName is a destination naming label, not a remote SQL connection. NULL uses @@servername; otherwise the supplied name replaces it in the server/instance prefix. A name without an instance uses MSSQLSERVER; a backslash separates a named instance. The procedure always backs up databases on the instance where it executes.

## Additional backup options

OtherBackupOptions is appended unchanged after generated compression,
DIFFERENTIAL and read-only COPY_ONLY options. NULL or whitespace omits extras.
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
`.diff` or `.trn`. Timestamp tokens use one SQL Server local datetime2(7) value;
`fffffff` writes seven fractional-second digits. Clock accuracy and uniqueness
are not implied by the number of digits. See [date/time formatting](https://learn.microsoft.com/en-us/dotnet/standard/base-types/custom-date-and-time-format-strings).

BackupFileNameFormat supplies the filename without its extension. Supported
replacement tokens are `{ServerName}`, `{InstanceName}`, `{DatabaseName}`,
`{BackupType}`, `{yyyyMMdd}`, `{HHmmssfffffff}`, `{HHmmssffffff}`, `{HHmmss}`,
`{fffffff}` and `{ffffff}`.
For example:

```sql
-- Omit the instance explicitly.
exec z.usp_BackupDatabase @Databases = N'Sales',
    @BackupFileNameFormat = N'{ServerName}${DatabaseName}_{yyyyMMdd}_{HHmmssfffffff}';

-- Use the former database-only, six-digit convention.
exec z.usp_BackupDatabase @Databases = N'Sales',
    @BackupFileNameFormat = N'{DatabaseName}_{yyyyMMdd}_{HHmmss}_{ffffff}';
```

Components are transformed by [z.fn_StandardizeFileName](../../../docs/reference/functions.md#zfn_standardizefilename).
Custom layouts outside [recognized filename shapes](z.fn_DecodeBackupFileName.md)
use broader restore header discovery and require header-based cleanup.


## Azure and S3 destinations

Supply a container/bucket URL with an optional object prefix as BackupFolder, not a complete backup filename. `https://` selects Azure Blob URL handling; `s3://` selects S3-compatible storage. The procedure appends the same server/instance/database/type/file naming layout using `/`, preserving the URL and object-prefix case. These prefixes do not require directory creation. URL destinations never call filesystem enumeration, directory creation or cleanup.

Use preconfigured SQL Server credentials and storage permissions. Azure block-blob backups on Linux require SAS credentials. S3-compatible backup requires SQL Server 2022 or later; its `s3://` scheme uses HTTPS underneath. The procedure does not create storage accounts, containers, buckets or credentials. See [Azure requirements](https://learn.microsoft.com/en-us/sql/relational-databases/backup-restore/sql-server-backup-to-url) and [S3 requirements](https://learn.microsoft.com/en-us/sql/relational-databases/backup-restore/sql-server-backup-to-url-s3-compatible-object-storage).

## Execution and retention

Run outside a transaction. For a bounded pool across selected databases, use
[z.usp_BackupDatabasesParallel](z.usp_BackupDatabasesParallel.md). Independent
sequential calls do not share assignments. Filesystem backups need SQL Server service-account destination access. The main procedure requires no application-lock or extended-property write permissions.

Retention is separate. The removed RetentionHours and UseBackupHeaderToDetermineBackupDate parameters are no longer accepted. The sixth positional argument is now ServerName, so update positional callers as well as named retention arguments. Schedule [filesystem cleanup](z.usp_CleanupDatabaseBackups.md) separately from active backups; use storage lifecycle rules or separate provider tooling for URL retention. The backup procedure never deletes old backups.
