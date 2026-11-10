# z.fn_DecodeBackupFileName

[Backup](../readme.md) | [Source](../../modules/1010%20Functions/z.fn_DecodeBackupFileName.sql)

Decodes recognized backup filename hints without opening a backup file.

```sql
select * from z.fn_DecodeBackupFileName(N'SQL1$Sales_20261108_1430251234567.trn');
```

The inline table-valued function accepts FileName nvarchar(4000) and returns zero
rows for an unrecognized extension, timestamp or component layout. Recognized
extensions are `.bak` (1), `.diff` (5) and `.trn` (2).

| Column | Meaning |
| --- | --- |
| Prefix | Filename prefix before the timestamp, including server/instance components |
| DatabaseName | Database-name hint from the filename |
| BackupTime | Parsed local timestamp as datetime2(7) |
| BackupType | FULL = 1, DIFF = 5, LOG = 2 |
| SourceServerName | Server label, or NULL for the legacy database-only convention |
| SourceInstanceName | Instance label when present, otherwise NULL |

Recognized examples:

```text
Sales_20261108_143025_123456.bak
SQL1$Sales_20261108_1430251234567.bak
SQL1$Reporting$Sales_20261108_1430251234567.trn
```

Six or seven fractional digits are accepted, with or without the separator before
the fraction. The server, instance and database components use `$` separators;
the default format includes MSSQLSERVER for the default instance. Custom formats
may omit the instance component. Custom layouts outside these shapes
require header-based discovery and header-based cleanup. Literal `$` characters
within components can make filename hints ambiguous; headers remain authoritative.
This helper does not establish database identity, recovery lineage or LSN coverage.
