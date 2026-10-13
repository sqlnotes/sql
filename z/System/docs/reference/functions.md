# System functions reference

[Object index](readme.md)

Functions do not execute generated SQL or start transactions. Grant SELECT/EXECUTE access according to object type. Catalog-based helpers require metadata visibility; other helpers use supplied values and built-ins. Defaults are exactly those shown.

Schema-copy generation now belongs to `z.usp_CopyTableSchema`. The former `z.fn_BuildQueryCopyTableSchema` is retired; use `@ShowPlan = 1` on the procedure to return its ordered script rows without execution. See [schema copy](schema-copy.md).

## z.fn_BuildQueryMergeTable

[Source](../../modules/1030%20Functions/z.fn_BuildQueryMergeTable.sql)

```sql
create or alter function z.fn_BuildQueryMergeTable
(
	@TargetTableName nvarchar(300),
	@ForceIdentityColumnInsert bit = 1,
	@PrimaryKeys nvarchar(max) = null,
	@ExcludedColumns varchar(max) = null
)
returns table
```

Returns Query plus TargetTableName, HasIdentity, ContainNoneKeyColumn, MergeKey, InsertColumnList, InsertValueList, UpdateWhereClause, UpdateValueList. Generates a merge template with a source-query placeholder using `z.v_Objects`; it does not execute the merge. Keys default to the catalog primary key. Explicit `@PrimaryKeys` and `@ExcludedColumns` are comma-separated raw column names with outer spaces trimmed, not bracketed SQL fragments. Generated column references use `quotename()`, including reserved words and embedded closing brackets; computed and rowversion columns are omitted. Identity omission/legacy LOB branches can still generate invalid SQL; see [troubleshooting](../troubleshooting.md).

## z.fn_DecodeZSequenceID

[Source](../../modules/1010%20Functions/z.fn_DecodeZSequenceID.sql)

```sql
create or alter function z.fn_DecodeZSequenceID(@SequenceID bigint)
returns table
```

Returns one-row table Date datetime and Sequence bigint, decoding seconds since 1900 and low 28 bits. No input validation.

## z.fn_GenerateRandomDate

[Source](../../modules/1010%20Functions/z.fn_GenerateRandomDate.sql)

```sql
create or alter function z.fn_GenerateRandomDate(@Rand float, @DateFrom datetime, @DateTo datetime)
returns datetime
```

Returns datetime based on supplied Rand (normally 0<=Rand<1). Null endpoints default to one year before/after current local time. Does not generate randomness or validate range.

## z.fn_GenerateZSequenceID

[Source](../../modules/1010%20Functions/z.fn_GenerateZSequenceID.sql)

```sql
create or alter function z.fn_GenerateZSequenceID(@Date datetime, @SeqGeneralID bigint)
returns bigint
```

Returns bigint combining datetime seconds since 1900 and sequence via bitwise OR. A null `@Date` uses the current UTC time; a supplied date is used unchanged, with second precision in the encoded ID. Sequence must fit 28 bits. No sequence allocation or validation; repeated inputs within a second repeat.

System deployment removes `z.fn_GetZSequenceID` in [DeprecatedObject.sql](../../post/DeprecatedObject.sql). Replace calls to `z.fn_GetZSequenceID(@Sequence)` with `z.fn_GenerateZSequenceID(null, @Sequence)` before deploying, including application queries and database objects outside this library. Schema-bound dependencies can prevent removal.

## z.fn_GetColumnReferencesFromQueryPlan

[Source](../../modules/1010%20Functions/z.fn_GetColumnReferencesFromQueryPlan.sql)

```sql
create or alter function z.fn_GetColumnReferencesFromQueryPlan(@ExecutionPlan xml)
returns table
```

Returns distinct ServerName, DatabaseName, SchemaName, ObjectName, ColumnName from XML `ColumnReference` nodes. It reads each attribute as `nvarchar(200)` and removes every opening and closing bracket. Rows with NULL extracted database/schema/object/column values are excluded; explicit empty-string values are not separately filtered. Server identity can be absent. The function does not retrieve plans or inspect `Object` nodes, so a table referenced only by an object node, such as a plan for `count(*)`, can be absent.

Bracket removal can corrupt names containing literal brackets or escaped `]]`, and extraction can truncate long escaped identifiers. Plan references can include access-path columns or underlying view/synonym objects and omit references eliminated by optimization; they are not a complete list of names from the query text. These limitations remain in the current implementation.

## z.fn_GetExpectedName

[Source](../../modules/1010%20Functions/z.fn_GetExpectedName.sql)

```sql
create or alter function z.fn_GetExpectedName
(
	@Type varchar(50), -- Index, UniqueKey, PrimaryKey, ColumnStore, ForeignKey, Default
	@ParentSchemaName sysname,
	@ParentObjectName sysname,
	@Columns nvarchar(max), --col1,col2...no space
	@ReferencedSchemaName sysname,
	@ReferencedObjectName sysname
)
returns nvarchar(128)
```

Returns nvarchar(128) index/constraint name for Index, UniqueKey, PrimaryKey, columnstore, ForeignKey, Default or XML kinds. Unsupported type returns null; long names can truncate/collide.

## z.fn_GetFullErrorMessage

[Source](../../modules/1010%20Functions/z.fn_GetFullErrorMessage.sql)

```sql
create or alter function z.fn_GetFullErrorMessage()
returns nvarchar(max)
```

Returns nvarchar(max) formatted ERROR_* context; null outside catch context. Does not throw/log.

## z.fn_GetLastCommittedRowVersion

[Source](../../modules/1010%20Functions/z.fn_GetLastCommittedRowVersion.sql)

```sql
create or alter function z.fn_GetLastCommittedRowVersion()
returns binary(8)
```

Returns binary(8), one less than min_active_rowversion(), with signed bigint minimum handled. Capture this inclusive watermark before polling changes with RowVersion > previous watermark and RowVersion <= current watermark. With no active rowversions, it equals @@dbts; otherwise, later committed values can be deferred. The watermark need not identify an existing committed row and does not determine snapshot visibility.

## z.fn_GetPeriodStart

[Source](../../modules/1010%20Functions/z.fn_GetPeriodStart.sql)

```sql
create or alter function z.fn_GetPeriodStart
(
	@Date datetime,
	@Period varchar(20), --'Second', 'Minute', 'Hourly', 'Daily', 'Weekly', 'Monthly', 'Yearly'
	@Interval int,
	@StartDate datetime2 = null
)
returns datetime
```

Returns datetime period start for Second, Minute, Hourly, Daily, Weekly, Monthly or Yearly. Default anchor is year 0006; Weekly depends on @@datefirst. Positive interval required but not validated. Arithmetic/return range can fail.

## z.fn_IsAmazonRDS

[Source](../../modules/1010%20Functions/z.fn_IsAmazonRDS.sql)

```sql
create or alter function z.fn_IsAmazonRDS()
returns bit
```

Returns bit from EC2AMAZ server-name heuristic and visible rdsadmin.dbo.rds_configuration. Permissions/naming may yield false negatives.

## z.fn_IsAzureDatabase

[Source](../../modules/1010%20Functions/z.fn_IsAzureDatabase.sql)

```sql
create or alter function z.fn_IsAzureDatabase()
returns bit
```

Returns bit 0 in both branches, including SQL Azure. Cannot currently detect Azure.

## z.fn_IsHostedDatabase

[Source](../../modules/1020%20Functions/z.fn_IsHostedDatabase.sql)

```sql
create or alter function z.fn_IsHostedDatabase()
returns bit
```

Returns bit from Amazon RDS or Azure helpers. Azure helper always returns 0.

## z.fn_IsLinux

[Source](../../modules/1010%20Functions/z.fn_IsLinux.sql)

```sql
create or alter function z.fn_IsLinux()
returns bit
```

Returns bit from linux string in @@version, subject to collation.

## z.fn_AsciiLettersOnly

[Source](../../modules/1010%20Functions/z.fn_AsciiLettersOnly.sql)

```sql
create or alter function z.fn_AsciiLettersOnly(@str varchar(max))
returns nvarchar(max)
```

Returns nvarchar(max) retaining ASCII letters from varchar input via byte translation. Not a Unicode alphabetic filter; NULL input returns NULL.

Formerly `z.fn_LettersOnly`; update callers before deploying. System post removes the old name.

## z.fn_DigitsOnly

[Source](../../modules/1010%20Functions/z.fn_DigitsOnly.sql)

```sql
create or alter function z.fn_DigitsOnly(@str varchar(max))
returns nvarchar(max)
```

Returns nvarchar(max) retaining ASCII digits `0` through `9` from varchar input. Signs, decimal separators and other characters are removed; NULL input returns NULL.

Formerly `z.fn_NumbersOnly`; update callers before deploying. System post removes the old name.

## z.fn_SplitLines

[Source](../../modules/1010%20Functions/z.fn_SplitLines.sql)

```sql
create or alter function z.fn_SplitLines
(
	@Str nvarchar(max)
)
returns table
```

Returns Ordinal/Value rows splitting CR/LF recursively. Empty/null input gives no rows. For input without supplementary Unicode characters, leading, repeated and trailing separators retain empty values, including a final empty row after a trailing separator. Select ordered explicitly; long input may need maxrecursion override.

Formerly `z.fn_ReadLinesFromString`; update callers before deploying. System post removes the old name. The current implementation also treats adjacent LFCR as one separator and can include newline characters in the last row for supplementary Unicode under SC collations.

## z.fn_FormatDurationSeconds

[Source](../../modules/1010%20Functions/z.fn_FormatDurationSeconds.sql)

```sql
create or alter function z.fn_FormatDurationSeconds(@Seconds bigint)
returns varchar(30)
```

Returns varchar(30) for absolute seconds: `MM:ss` below one hour, `HH:MM:ss` from one hour, and `days.HH:MM:ss` from one day. For example, 65 produces `01:05`, 3600 produces `01:00:00`, and 86400 produces `1.00:00:00`. The sign is discarded; NULL returns NULL and `abs(bigint minimum)` overflows. Uses `format()`.

Formerly `z.fn_SecondsToTimeString`; update callers before deploying. System post removes the old name.

## z.fn_ShouldSkipTrigger

[Source](../../modules/1010%20Functions/z.fn_ShouldSkipTrigger.sql)

```sql
create or alter function z.fn_ShouldSkipTrigger(@TriggerID int)
returns bit
```

Returns bit from session-context SkipTriggerFlag (all or ID list). Only triggers explicitly consulting this helper honor it. See coordination.

## z.fn_SplitString

[Source](../../modules/1010%20Functions/z.fn_SplitString.sql)

```sql
create or alter function z.fn_SplitString
(
	@Str nvarchar(max),
	@Separator nvarchar(100)
)
returns table
```

Returns Ordinal/Value for a possibly multicharacter separator. Empty/null input or separator gives no rows. Recursion limit can require override; select ordered explicitly.

## z.fn_SplitStringFixedLength

[Source](../../modules/1010%20Functions/z.fn_SplitStringFixedLength.sql)

```sql
create or alter function z.fn_SplitStringFixedLength
(
	@Str nvarchar(max),
	@Length int
)
returns table
```

Returns Ordinal/Value chunks of positive length. Invalid length gives no rows; recursive queries may require override.

## z.fn_SqlVariantToDateTime

[Source](../../modules/1010%20Functions/z.fn_SqlVariantToDateTime.sql)

```sql
create or alter function z.fn_SqlVariantToDateTime
(
	@value sql_variant
)
returns table
```

Returns one row BaseDataType varchar(128), Value datetime. Bigint decoded as System ID; uniqueidentifier maps to null; others try_cast. Intermediate arithmetic may overflow.

## z.fn_ZSequenceIDToDatetime

[Source](../../modules/1010%20Functions/z.fn_ZSequenceIDToDatetime.sql)

```sql
create or alter function z.fn_ZSequenceIDToDatetime(@SequenceID bigint)
returns datetime
```

Returns datetime decoded from high bits of bigint; sequence bits ignored. Does not validate genuine ID.
