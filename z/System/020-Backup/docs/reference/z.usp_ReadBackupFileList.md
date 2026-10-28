# z.usp_ReadBackupFileList

[Backup objects](readme.md) | [Header reader](z.usp_ReadBackupHeader.md)

Reads the database files described by one backup set and returns all 22 documented FILELISTONLY columns. SQL Server 2019, 2022 and 2025 use this layout. The procedure reads the backup directly without depending on msdb history or restoring a database.

## Parameters

| Parameter | Type | Meaning |
| --- | --- | --- |
| `@BackupFile` | `nvarchar(4000)` | Required disk path or full HTTPS/S3 backup-object URL. |
| `@Position` | `int = 1` | Required positive backup-set position within the media file. |
| `@FileListJson` | `nvarchar(max) = null output` | JSON array containing all file-list fields, including NULL properties. |
| `@ReturnResult` | `bit = 1` | Return tabular rows. Set to 0 to consume only JSON. |

HTTPS/S3 URLs use FROM URL; other inputs use FROM DISK. S3 requires SQL Server 2022+. Paths retain their case and separators. Credentials, storage permissions and native CREATE DATABASE permission remain the caller's responsibility. No directory checks, folder creation, backup deletion or privilege elevation occur.

## Example

```sql
declare @Files nvarchar(max);
exec z.usp_ReadBackupFileList
    @BackupFile = N'D:\Backups\MyDatabase.bak',
    @Position = 1,
    @FileListJson = @Files output,
    @ReturnResult = 0;

select LogicalName, PhysicalName, Type, FileGroupName, Size, IsPresent
from z.fn_DecodeBackupFileList(@Files)
order by FileID;
```

[DecodeBackupFileList](z.fn_DecodeBackupFileList.md) returns typed rows that callers can filter, join, or insert into their own tables using INSERT SELECT. The reader internally captures native results with INSERT EXEC, so an outer INSERT EXEC around this procedure is prohibited. Use the JSON output and decoder instead.

## Output

Rows are ordered by FileID. The complete native field set is:

- LogicalName, PhysicalName, Type and FileGroupName.
- Size, MaxSize, FileID, BackupSizeInBytes, SourceBlockSize and FileGroupID.
- CreateLSN, DropLSN, ReadOnlyLSN, ReadWriteLSN, UniqueID and LogGroupGUID.
- DifferentialBaseLSN, DifferentialBaseGUID, IsReadOnly and IsPresent.
- TDEThumbprint and SnapshotURL.

Type identifies data, log and special file/container types. IsPresent indicates whether the file is present in the backup; do not assume every listed file is included. Sizes and LSNs keep their documented exact numeric types. Binary thumbprints are base64 in JSON and return as varbinary through the decoder. See [Microsoft's field definitions](https://learn.microsoft.com/en-us/sql/t-sql/statements/restore-statements-filelistonly-transact-sql).

## Compatibility and limits

Unknown SQL Server major versions are rejected rather than assumed compatible. The helper accepts one physical backup file/object and one backup-set position per call. It does not assemble striped media, configure region options, verify file contents or generate a restore plan. Native media, permission, encryption and compatibility errors propagate.

Consume output only after successful execution. On failure, callers must not rely on the previous output-variable value being replaced. Header/file metadata inspection does not prove a complete usable restore chain.

## Definition

[SQL source](../../modules/1070%20Procedures/z.usp_ReadBackupFileList.sql)
