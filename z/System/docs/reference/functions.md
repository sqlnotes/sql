# System functions reference

[Object index](readme.md)

Functions do not execute generated SQL or start transactions. Grant SELECT/EXECUTE access according to object type. Catalog-based helpers require metadata visibility; other helpers use supplied values and built-ins. Defaults are exactly those shown.

## z.fn_BuildQueryCopyTableSchema

[Source](../../modules/1030%20Functions/z.fn_BuildQueryCopyTableSchema.sql)

```sql
create or alter function z.fn_BuildQueryCopyTableSchema
(
	@FullSourceTableName nvarchar(256),
	@FullTargetTableName nvarchar(256),
	@FileGroupOrPartitionScheme nvarchar(128), -- NULL: 'Use Source Object File Group', 'Use default Database File Group', 'Use Source Object Partition Scheme', FileGroupName or PartitionSchemeName(FieldName)
	@CopyIdentity bit,
	@DataCompression varchar(20)
)
returns @ret table (Ordinal int, PartName varchar(30), Definition nvarchar(max))
```

Returns Ordinal int, PartName varchar(30), Definition nvarchar(max). Generates table/index/default DDL without executing it. Catalog visibility and resolved storage needed. See schema-copy limits.

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

Returns Query plus TargetTableName, HasIdentity, ContainNoneKeyColumn, MergeKey, InsertColumnList, InsertValueList, UpdateWhereClause, UpdateValueList. Generates merge template with source placeholder using z.v_Objects. Identity omission/legacy LOB branches can generate invalid SQL; see troubleshooting.

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

Returns bigint combining datetime seconds since 1900 and sequence via bitwise OR. Sequence must fit 28 bits. No sequence allocation or validation.

## z.fn_GetColumnReferencesFromQueryPlan

[Source](../../modules/1010%20Functions/z.fn_GetColumnReferencesFromQueryPlan.sql)

```sql
create or alter function z.fn_GetColumnReferencesFromQueryPlan(@ExecutionPlan xml)
returns table
```

Returns distinct ServerName, DatabaseName, SchemaName, ObjectName, ColumnName from XML ColumnReference nodes, stripping brackets. Excludes rows lacking database/schema/object/column. Does not retrieve plans.

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

Returns binary(8), one less than min_active_rowversion(), with signed bigint minimum handled. A rowversion watermark, not a time or independent visibility guarantee.

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

## z.fn_GetZSequenceID

[Source](../../modules/1010%20Functions/z.fn_GetZSequenceID.sql)

```sql
create or alter function z.fn_GetZSequenceID(@SeqGeneralID bigint)
returns bigint
```

Returns bigint combining current UTC seconds since 1900 and supplied sequence. Does not consume z.SeqGeneralID; repeated inputs within a second repeat.

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

## z.fn_LettersOnly

[Source](../../modules/1010%20Functions/z.fn_LettersOnly.sql)

```sql
create or alter function z.fn_LettersOnly(@str varchar(max))
returns nvarchar(max)
```

Returns nvarchar(max) retaining ASCII letters from varchar input via byte translation. Not a Unicode alphabetic filter.

## z.fn_NumbersOnly

[Source](../../modules/1010%20Functions/z.fn_NumbersOnly.sql)

```sql
create or alter function z.fn_NumbersOnly(@str varchar(max))
returns nvarchar(max)
```

Returns nvarchar(max) retaining ASCII digits from varchar input.

## z.fn_ReadLinesFromString

[Source](../../modules/1010%20Functions/z.fn_ReadLinesFromString.sql)

```sql
create or alter function z.fn_ReadLinesFromString
(
	@Str nvarchar(max)
)
returns table
```

Returns Ordinal/Value rows splitting CR/LF recursively. Empty/null input gives no rows. Select ordered explicitly; long input may need maxrecursion override.

## z.fn_SecondsToTimeString

[Source](../../modules/1010%20Functions/z.fn_SecondsToTimeString.sql)

```sql
create or alter function z.fn_SecondsToTimeString(@Seconds bigint)
returns varchar(30)
```

Returns varchar(30), absolute seconds formatted optional days.hours:minutes:seconds. Sign discarded; abs(bigint minimum) overflows. Uses FORMAT.

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
