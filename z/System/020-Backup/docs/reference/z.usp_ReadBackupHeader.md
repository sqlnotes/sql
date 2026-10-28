# z.usp_ReadBackupHeader

[Backup objects](readme.md) | [Usage](../usage.md)

Reads backup headers and returns the same 59 documented columns on SQL Server 2019, 2022 and 2025. It reads backup media directly, without depending on `msdb` backup history or restoring a database. The version of the SQL Server executing the command determines the input layout.

## Parameters

| Parameter | Type | Meaning |
| --- | --- | --- |
| `@BackupFile` | `nvarchar(4000)` | Required filesystem path or full Azure HTTPS/S3 URL to a backup file. |
| `@Position` | `int = null` | Backup-set position within the file. NULL reads all sets; a supplied value must be positive. |
| `@HeaderJson` | `nvarchar(max) = null output` | JSON array of the same header rows, including NULL properties. Cleared when execution starts. |
| `@ReturnResult` | `bit = 1` | Return the tabular result. Set to 0 when consuming only the JSON output. |

The procedure routes HTTPS and S3 URLs to `RESTORE HEADERONLY FROM URL`; all other values use `FROM DISK`. It preserves the supplied path and URL. S3 requires SQL Server 2022+. SQL Server credentials, filesystem access and storage permissions must already be configured. It does not enumerate directories, create folders, delete backups or contact storage before the native command.

## Examples

```sql
exec z.usp_ReadBackupHeader
    @BackupFile = N'D:\Backups\MyDatabase.bak';

exec z.usp_ReadBackupHeader
    @BackupFile = N'https://example.blob.core.windows.net/backups/MyDatabase.bak',
    @Position = 1;
```

For Linux, pass a filesystem path such as `/var/opt/mssql/backup/MyDatabase.bak`. S3 uses a full object URL such as `s3://example-bucket.s3.us-east-2.amazonaws.com/backups/MyDatabase.bak`.

## Output

All native header fields are preserved, including:

- Names, backup-set position/type/description, creation/start/finish/expiration dates, source server/machine and software versions.
- FirstLSN, LastLSN, CheckpointLSN, DatabaseBackupLSN, DifferentialBaseLSN, ForkPointLSN, database-family/binding/backup-set GUIDs and recovery-fork IDs.
- Recovery model, differential-base GUID, copy-only and log-chain flags, checksum/damage/incomplete-metadata flags, read-only/snapshot/single-user flags.
- Sizes, compression, encryption algorithm/thumbprint/type, collation, compatibility, containment and legacy header fields.
- LastValidRestoreTime, TimeZone and CompressionAlgorithm, which return NULL on SQL Server 2019.

Rows are ordered by Position. Numeric LSNs remain `numeric(25,0)` in the tabular result. The complete field definitions are in [Microsoft's HEADERONLY reference](https://learn.microsoft.com/en-us/sql/t-sql/statements/restore-statements-headeronly-transact-sql).

## Consuming headers in T-SQL

The procedure internally uses `insert ... exec` to capture native headers. SQL Server prohibits nesting that operation, so callers must not use `insert ... exec z.usp_ReadBackupHeader`. Use the JSON output instead:

```sql
declare @Headers nvarchar(max);
exec z.usp_ReadBackupHeader
    @BackupFile = N'D:\Backups\MyDatabase_Log.trn',
    @HeaderJson = @Headers output,
    @ReturnResult = 0;

select Position, DatabaseName, FirstLSN, LastLSN, FamilyGUID, RecoveryForkID
from z.fn_DecodeBackupHeader(@Headers);
```

Use explicit numeric types when parsing LSNs; floating-point parsing can lose precision. Binary fields in JSON use SQL Server's base64 representation. Treat the output as valid only after successful execution; on an error, callers must not rely on their previous output-variable value being replaced.

## Compatibility and limits

SQL Server 2019 emits 56 native columns; SQL Server 2022/2025 emit 59. The helper captures the appropriate layout and fills the three newer columns with NULL for 2019. Unknown engine major versions are rejected rather than assumed compatible. Additional native layout changes require an updated adapter.

This interface accepts one physical backup file/object per call. It does not assemble striped media, configure region options, construct a restore sequence, verify backup contents or prove that a restore chain is usable. Native permissions, missing/corrupt media, encryption-key requirements and compatibility errors propagate. Reading a header does not make an older SQL Server capable of restoring a newer backup. Native `RESTORE HEADERONLY` requires CREATE DATABASE permission; the helper grants no extra privileges.

## Definition

[SQL source](../../modules/1070%20Procedures/z.usp_ReadBackupHeader.sql)

Use [z.fn_DecodeBackupHeader](z.fn_DecodeBackupHeader.md) to decode every header field with its original SQL type, including binary thumbprints.
