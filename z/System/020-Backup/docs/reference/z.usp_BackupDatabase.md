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
@ServerName sysname = null
```

Databases accepts AllDatabases, UserDatabases, SystemDatabases or comma-separated names. Exclude tempdb and error/recovery states; skip SIMPLE recovery for LOG. Read-only databases automatically include COPY_ONLY for disk and URL backups. SQL Server honors it for FULL and LOG; with DIFFERENTIAL it has no effect and the requested type remains DIFF. Read-write backups use COPY_ONLY only when explicitly supplied in OtherBackupOptions. Compression NULL uses the server default. OtherBackupOptions supplies trusted SQL options, including an existing credential option where appropriate.

ServerName is a destination naming label, not a remote SQL connection. NULL uses @@servername; otherwise the supplied name replaces it in the server/instance prefix. A name without an instance uses MSSQLSERVER; a backslash separates a named instance. The procedure always backs up databases on the instance where it executes.

## Backup option deduplication

Options are compared by name without case sensitivity. The last user occurrence wins; its text and value are retained. For example, `STATS=1, stats=5` emits only `stats=5`. Generated compression, DIFFERENTIAL and readonly COPY_ONLY options are added only when the corresponding option is absent.

Opposing flags share a key: COMPRESSION/NO_COMPRESSION, INIT/NOINIT, FORMAT/NOFORMAT, CHECKSUM/NO_CHECKSUM, SKIP/NOSKIP, REWIND/NOREWIND, UNLOAD/NOUNLOAD and STOP_ON_ERROR/CONTINUE_AFTER_ERROR. Thus a caller compression option overrides the BackupCompression-derived default. Winning user options retain their relative order.

Commas inside quoted values, bracketed identifiers and parentheses do not split an option. Quoted escapes and comments are preserved; output separators include newlines so line comments cannot swallow subsequent options. Unbalanced delimiters are rejected. Deduplication does not validate every native option/value combination or make the trusted SQL input safe for untrusted callers.

## Filesystem destinations

A NULL BackupFolder uses InstanceDefaultBackupPath. The folder is trimmed; Windows non-URL paths normalize `/` to `\`, including `//server/share` UNC paths. Linux keeps `/`. Paths are not prevalidated; native directory creation and BACKUP determine usability. Missing directories are created before `BACKUP TO DISK`.

Files use `<root>/<server>/<instance>/<database>/<type>/<database>_yyyyMMdd_HHmmss_ffffff` followed by .bak, .diff or .trn. Filesystem separators follow the host platform. The timestamp uses SQL Server local time with six fractional-second digits.

## Azure and S3 destinations

Supply a container/bucket URL with an optional object prefix as BackupFolder, not a complete backup filename. `https://` selects Azure Blob URL handling; `s3://` selects S3-compatible storage. The procedure appends the same server/instance/database/type/file naming layout using `/`, preserving the URL and object-prefix case. These prefixes do not require directory creation. URL destinations never call filesystem enumeration, directory creation or cleanup.

Use preconfigured SQL Server credentials and storage permissions. Azure block-blob backups on Linux require SAS credentials. S3-compatible backup requires SQL Server 2022 or later; its `s3://` scheme uses HTTPS underneath. The procedure does not create storage accounts, containers, buckets or credentials. See [Azure requirements](https://learn.microsoft.com/en-us/sql/relational-databases/backup-restore/sql-server-backup-to-url) and [S3 requirements](https://learn.microsoft.com/en-us/sql/relational-databases/backup-restore/sql-server-backup-to-url-s3-compatible-object-storage).

## Execution and retention

Run outside a transaction and schedule one invocation at a time. Filesystem backups need SQL Server service-account destination access. The main procedure requires no application-lock or extended-property write permissions.

Retention is separate. The removed RetentionHours and UseBackupHeaderToDetermineBackupDate parameters are no longer accepted. The sixth positional argument is now ServerName, so update positional callers as well as named retention arguments. Schedule [filesystem cleanup](z.usp_CleanupDatabaseBackups.md) separately from active backups; use storage lifecycle rules or separate provider tooling for URL retention. The backup procedure never deletes old backups.
