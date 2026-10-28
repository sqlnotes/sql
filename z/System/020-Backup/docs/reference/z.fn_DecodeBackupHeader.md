# z.fn_DecodeBackupHeader

[Backup objects](readme.md) | [Header reader](z.usp_ReadBackupHeader.md)

An inline table-valued function that decodes the HeaderJson output from z.usp_ReadBackupHeader. It returns all 59 header columns in the same order and SQL types as the reader, including numeric(25,0) LSNs, GUIDs, datetime values, bit flags and a varbinary(20) EncryptorThumbprint.

## Parameter and behavior

`@HeaderJson nvarchar(max)` is the reader's JSON array. SQL NULL and an empty array return no rows. Missing properties return NULL, and unknown properties are ignored. Property names are case-sensitive. Use the reader's output with its original property names.

EncryptorThumbprint is decoded from JSON base64 into binary; it is not interpreted as a hexadecimal string. Newer fields remain NULL when the reader reports a SQL Server 2019 layout. Malformed JSON and invalid SQL-type conversions surface native errors. Invalid base64 can decode to NULL under the XML conversion rules. The function is a decoder for reader output, not a general JSON validation interface.

OPENJSON requires database compatibility level 130 or higher. No backup access, disk/network operation, stored procedure call or permission elevation occurs inside this function. Result order is not guaranteed; use ORDER BY when needed.

## Example

```sql
declare @Headers nvarchar(max);
exec z.usp_ReadBackupHeader
    @BackupFile = N'D:\Backups\MyDatabase.bak',
    @HeaderJson = @Headers output,
    @ReturnResult = 0;

select * into #Headers
from z.fn_DecodeBackupHeader(@Headers);

select DatabaseName, BackupTypeDescription, FirstLSN, LastLSN, RecoveryForkID
from #Headers
order by Position;
```

For an existing destination table, use INSERT INTO with an explicit column list followed by SELECT from this function. Typed decoding preserves LSN precision without caller-written OPENJSON mappings. See the [reader reference](z.usp_ReadBackupHeader.md) for the full output contract and media-access limits.

## Definition

[SQL source](../../modules/1010%20Functions/z.fn_DecodeBackupHeader.sql)
