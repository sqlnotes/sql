# z.fn_DecodeBackupFileList

[Backup objects](readme.md) | [File-list reader](z.usp_ReadBackupFileList.md)

An inline table-valued function that decodes the FileListJson output from z.usp_ReadBackupFileList. It returns all 22 file-list columns in the same order and SQL types as the reader, including exact sizes/LSNs, GUIDs, bit flags and a varbinary(32) TDEThumbprint.

## Parameter and behavior

`@FileListJson nvarchar(max)` is the reader's JSON array. SQL NULL and an empty array return no rows. Missing properties return NULL, unknown properties are ignored, and property names are case-sensitive. The function expects the original reader property names.

TDEThumbprint is decoded from JSON base64 into binary. Malformed JSON and invalid SQL-type conversions surface native errors. Invalid base64 can decode to NULL under the XML conversion rules. This function decodes reader output; it is not a general JSON validation interface. OPENJSON requires database compatibility level 130 or higher.

The function reads no backup media and performs no disk/network access or permission elevation. Result order is not guaranteed; use ORDER BY FileID when needed.

## Example

```sql
declare @Files nvarchar(max);
exec z.usp_ReadBackupFileList
    @BackupFile = N'D:\Backups\MyDatabase.bak',
    @FileListJson = @Files output,
    @ReturnResult = 0;

select * into #Files
from z.fn_DecodeBackupFileList(@Files);

select LogicalName, PhysicalName, Type, Size, IsPresent
from #Files
order by FileID;
```

To populate an existing table, use INSERT INTO with an explicit column list followed by SELECT from this function. See the [reader reference](z.usp_ReadBackupFileList.md) for every output field and media-access limits.

## Definition

[SQL source](../../modules/1010%20Functions/z.fn_DecodeBackupFileList.sql)
