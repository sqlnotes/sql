# System functions reference

[Object index](readme.md)

These helpers work with text, dates, identifiers, errors and SQL Server metadata. Choose the function for the result you need, then use its declaration for exact argument types and defaults. Functions that generate SQL return it for you to review and execute; they do not apply it themselves. Catalog-based results depend on the metadata your login can see.

Schema-copy generation now belongs to `z.usp_CopyTableSchema`. The former `z.fn_BuildQueryCopyTableSchema` is retired; use `@ShowPlan = 1` on the procedure to return its ordered script rows without execution. See [schema copy](schema-copy.md).

## z.fn_BuildQueryMergeTable

Builds a merge-script template for an existing table. Use it when preparing an initialization or synchronization script; replace the source-query placeholder before executing the result.

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

The returned `Query` is the script template. Other columns describe the target, its keys and the generated insert/update lists: `TargetTableName`, `HasIdentity`, `ContainNoneKeyColumn`, `MergeKey`, `InsertColumnList`, `InsertValueList`, `UpdateWhereClause` and `UpdateValueList`.

Keys default to the table's primary key. To override them or omit columns, pass comma-separated column names in `@PrimaryKeys` or `@ExcludedColumns`, without SQL brackets; spaces around each name are trimmed. Computed and rowversion columns are omitted. Set `@ForceIdentityColumnInsert = 0` to leave identity columns out of the insert lists. Generated column references are quoted so reserved words and embedded brackets remain valid identifiers.

## z.fn_DecodeZSequenceID

Splits a Schema Z bigint identifier into its timestamp and sequence number. Use it with identifiers created by `z.fn_GenerateZSequenceID`.

[Source](../../modules/1010%20Functions/z.fn_DecodeZSequenceID.sql)

```sql
create or alter function z.fn_DecodeZSequenceID(@SequenceID bigint)
returns table
```

Returns one row with `Date` (`datetime`) and `Sequence` (`bigint`). It decodes any supplied value without checking that it was originally generated as a Schema Z identifier.

## z.fn_GenerateRandomDate

Maps a supplied random fraction to a date within a chosen range. Generate the random fraction separately and pass it as `@Rand`.

[Source](../../modules/1010%20Functions/z.fn_GenerateRandomDate.sql)

```sql
create or alter function z.fn_GenerateRandomDate(@Rand float, @DateFrom datetime, @DateTo datetime)
returns datetime
```

Pass `@DateFrom` and `@DateTo` as the range endpoints and normally use `0 <= @Rand < 1`. A NULL endpoint defaults to one year before or after the current local time. The result is a `datetime`; the function does not validate the fraction or range.

## z.fn_GenerateZSequenceID

Creates a bigint identifier containing a timestamp and a sequence value. It works with `z.SeqGeneralID`; the matching decode helpers recover the timestamp or both components.

[Source](../../modules/1010%20Functions/z.fn_GenerateZSequenceID.sql)

```sql
create or alter function z.fn_GenerateZSequenceID(@Date datetime, @SeqGeneralID bigint)
returns bigint
```

A NULL `@Date` uses the current UTC time; otherwise the supplied timestamp is used, to the second. Supply a sequence value that fits in 28 bits. The function does not allocate that value or enforce uniqueness: repeating the same timestamp and sequence produces the same identifier. See the [usage example](../usage.md#generate-and-decode-an-identifier).

System deployment removes `z.fn_GetZSequenceID` in [DeprecatedObject.sql](../../post/DeprecatedObject.sql). Replace calls to `z.fn_GetZSequenceID(@Sequence)` with `z.fn_GenerateZSequenceID(null, @Sequence)` before deploying, including application queries and database objects outside this library. Schema-bound dependencies can prevent removal.

## z.fn_GetColumnReferencesFromQueryPlan

Lists column references found in an execution-plan XML value. Use it to inspect a plan you already have; it does not retrieve a plan or reconstruct every reference in the original SQL.

[Source](../../modules/1010%20Functions/z.fn_GetColumnReferencesFromQueryPlan.sql)

```sql
create or alter function z.fn_GetColumnReferencesFromQueryPlan(@ExecutionPlan xml)
returns table
```

Returns distinct `ServerName`, `DatabaseName`, `SchemaName`, `ObjectName` and `ColumnName` rows. References without a database, schema, object or column value are omitted; the server name can be absent. A table represented only as an object in the plan, such as in some `count(*)` plans, can be absent from these results.

Names are extracted into 200-character values with brackets removed, so long escaped identifiers or names containing literal brackets can be changed. Explicit empty strings are retained. Results can include access-path columns or underlying view/synonym objects, while optimization can remove other references. Treat this as plan inspection rather than a complete dependency inventory.

## z.fn_GetExpectedName

Builds the conventional name Schema Z expects for an index or constraint. Use it when creating objects or comparing existing names with the library's naming rules.

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

Choose the object kind with `@Type`, supply its parent schema/table, and provide key columns or the referenced table where that kind requires them. The result is a name of up to 128 characters. Supported kinds include Index, UniqueKey, PrimaryKey, columnstore, ForeignKey, Default and XML indexes. An unsupported kind returns NULL; long generated names can truncate or collide.

## z.fn_GetFullErrorJson

Formats the current SQL error as JSON for structured logging. Call it inside a `catch` block.

[Source](../../modules/1010%20Functions/z.fn_GetFullErrorJson.sql)

```sql
create or alter function z.fn_GetFullErrorJson()
returns nvarchar(max)
```

Returns one JSON object for the current `catch` context with `ErrorNumber`, `ErrorSeverity`, `ErrorState`, `ErrorProcedure`, `ErrorLine`, and `ErrorMessage`. Includes fields with null values and returns SQL NULL outside a `catch` context.

## z.fn_GetFullErrorMessage

Formats the current SQL error as readable text for a message or log. Call it inside a `catch` block.

[Source](../../modules/1010%20Functions/z.fn_GetFullErrorMessage.sql)

```sql
create or alter function z.fn_GetFullErrorMessage()
returns nvarchar(max)
```

Returns the error number, severity, state, procedure, line and message as one text value. Outside a `catch` block it returns NULL. The caller decides whether to print, store or raise the text.

## z.fn_GetLastCommittedRowVersion

Provides an upper watermark for polling rows changed since an earlier poll. Capture it before reading the changes so you can defer values that might still belong to active transactions.

[Source](../../modules/1010%20Functions/z.fn_GetLastCommittedRowVersion.sql)

```sql
create or alter function z.fn_GetLastCommittedRowVersion()
returns binary(8)
```

Read rows with `RowVersion > previous watermark` and `RowVersion <= current watermark`, then retain the current value for the next poll. The result is `binary(8)` and can defer some later committed values until a future poll. It need not identify an existing row or establish snapshot visibility. It is based on the oldest active rowversion and equals `@@dbts` when no rowversion is active.

## z.fn_GetPeriodStart

Finds the beginning of the time interval containing a date. Use it to group timestamps into periods such as five minutes, one week or three months, optionally aligned to your own starting date.

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

Returns the latest anchored boundary at or before `@Date` for Second, Minute, Hourly, Daily, Weekly, Monthly or Yearly. An interval of either sign uses its absolute width. Zero, NULL and unknown periods return NULL.

The default anchor is 2020-01-01 for nonweekly periods. Supply `@StartDate` to retain another alignment, including an anchor time within a day. Month and year boundaries use the original anchor day, clipping to the last day of a shorter month when necessary. Weekly boundaries start at Monday midnight independently of DATEFIRST, using the Monday of the supplied anchor's week or 1900-01-01 by default.

The result must fit SQL Server `datetime`. SQL Server 2019 and 2022 also require the final DATEADD offset to fit an int, which limits second offsets to about 68 years from the anchor.

## z.fn_IsAmazonRDS

Checks whether the current SQL Server appears to be hosted on Amazon RDS.

[Source](../../modules/1010%20Functions/z.fn_IsAmazonRDS.sql)

```sql
create or alter function z.fn_IsAmazonRDS()
returns bit
```

Returns a bit based on the server name and visible RDS configuration. This is a heuristic: naming or limited permissions can make an RDS instance return 0.

## z.fn_IsAzureDatabase

Identifies Azure SQL Database and Azure SQL Managed Instance so callers can choose the appropriate hosted-database behavior.

[Source](../../modules/1010%20Functions/z.fn_IsAzureDatabase.sql)

```sql
create or alter function z.fn_IsAzureDatabase()
returns bit
```

Returns 1 for Azure SQL Database (EngineEdition 5) and Azure SQL Managed Instance (8). Other engine editions return 0, including SQL Server on an Azure VM. [Engine edition values](https://learn.microsoft.com/en-us/sql/t-sql/functions/serverproperty-transact-sql)

## z.fn_IsHostedDatabase

Checks whether either the Amazon RDS or Azure database helper recognizes the current environment.

[Source](../../modules/1020%20Functions/z.fn_IsHostedDatabase.sql)

```sql
create or alter function z.fn_IsHostedDatabase()
returns bit
```

Returns 1 when either the Amazon RDS or Azure database helper identifies the environment.

## z.fn_IsLinux

Checks whether the SQL Server version text identifies a Linux host.

[Source](../../modules/1010%20Functions/z.fn_IsLinux.sql)

```sql
create or alter function z.fn_IsLinux()
returns bit
```

Returns a bit based on the presence of `linux` in `@@version`; matching follows the database collation.

## z.fn_ASCIILettersOnly

Removes everything except the English ASCII letters from a text value. Use it for simple text cleanup where non-ASCII letters should also be discarded.

[Source](../../modules/1010%20Functions/z.fn_ASCIILettersOnly.sql)

```sql
create or alter function z.fn_ASCIILettersOnly(@str varchar(max))
returns nvarchar(max)
```

Accepts `varchar` and returns `nvarchar(max)` containing only ASCII letters. NULL input returns NULL. This does not recognize letters from other alphabets.

Formerly `z.fn_LettersOnly`; update callers before deploying. System post removes the old name.

## z.fn_DigitsOnly

Keeps only digits `0` through `9` from a text value, for example when extracting digits from a formatted reference number.

[Source](../../modules/1010%20Functions/z.fn_DigitsOnly.sql)

```sql
create or alter function z.fn_DigitsOnly(@str varchar(max))
returns nvarchar(max)
```

Returns nvarchar(max) retaining ASCII digits `0` through `9` from varchar input. Signs, decimal separators and other characters are removed; NULL input returns NULL.

Formerly `z.fn_NumbersOnly`; update callers before deploying. System post removes the old name.

## z.fn_SplitLines

Turns multiline text into numbered rows. Use `Ordinal` to preserve the original order and `Value` for the text of each line.

[Source](../../modules/1010%20Functions/z.fn_SplitLines.sql)

```sql
create or alter function z.fn_SplitLines
(
	@Str nvarchar(max)
)
returns table
```

Accepts CR, LF and CRLF line endings. Empty or NULL input returns no rows; empty lines and trailing spaces are retained, including an empty final line after a trailing separator. Adjacent LF and CR characters produce an empty line between them. Supplementary Unicode characters are supported under `_SC` collations. Select with `order by Ordinal`; for more than 100 lines, add `option (maxrecursion 0)`.

Formerly `z.fn_ReadLinesFromString`; update callers before deploying. System post removes the old name.

## z.fn_FormatDurationMilliseconds

Formats a duration for display, keeping the number of days, time of day and milliseconds.

[Source](../../modules/1010%20Functions/z.fn_FormatDurationMilliseconds.sql)

`z.fn_FormatDurationMilliseconds(@Milliseconds bigint)` returns `varchar(32)` in
`days hh:mm:ss.fff` format. For example, 93784567 produces `1 02:03:04.567`.
Zero produces `0 00:00:00.000`; NULL returns NULL. Negative inputs retain a leading
minus sign, including bigint minimum. Uses arithmetic without FORMAT or datetime
conversion, so days do not wrap at 24 hours.

## z.fn_FormatDurationSeconds

Formats a duration in seconds as a readable time string. The format expands to include hours and days when needed.

[Source](../../modules/1010%20Functions/z.fn_FormatDurationSeconds.sql)

```sql
create or alter function z.fn_FormatDurationSeconds(@Seconds bigint)
returns varchar(30)
```

Returns varchar(30) for absolute seconds: `MM:ss` below one hour, `HH:MM:ss` from one hour, and `days.HH:MM:ss` from one day. For example, 65 produces `01:05`, 3600 produces `01:00:00`, and 86400 produces `1.00:00:00`. The sign is discarded; NULL returns NULL and `abs(bigint minimum)` overflows. Uses `format()`.

Formerly `z.fn_SecondsToTimeString`; update callers before deploying. System post removes the old name.

## z.fn_ShouldSkipTrigger

Lets a cooperating trigger check whether the current connection asked it to skip its work. Use it with `z.usp_SkipTrigger`.

[Source](../../modules/1010%20Functions/z.fn_ShouldSkipTrigger.sql)

```sql
create or alter function z.fn_ShouldSkipTrigger(@TriggerID int)
returns bit
```

Pass the trigger's object ID; the returned bit is 1 when the skip flag selects that trigger or all triggers. Only triggers written to consult this helper honor it. See [trigger flags](coordination.md#trigger-flags).

## z.fn_SplitString

Splits delimited text into numbered rows. Unlike a single-character splitter, it accepts a separator containing more than one character.

[Source](../../modules/1010%20Functions/z.fn_SplitString.sql)

```sql
create or alter function z.fn_SplitString
(
	@Str nvarchar(max),
	@Separator nvarchar(100)
)
returns table
```

Returns `Ordinal` and `Value`. Empty or NULL input or separator returns no rows. Select with `order by Ordinal` to retain input order; long lists can require `option (maxrecursion 0)`.

## z.fn_SplitStringFixedLength

Breaks text into chunks of a chosen length, for example when sending a long value to an output facility with a size limit.

[Source](../../modules/1010%20Functions/z.fn_SplitStringFixedLength.sql)

```sql
create or alter function z.fn_SplitStringFixedLength
(
	@Str nvarchar(max),
	@Length int
)
returns table
```

Supply a positive `@Length`. The result contains `Ordinal` and `Value` for each chunk; invalid lengths return no rows. Long inputs can require `option (maxrecursion 0)`. Select with `order by Ordinal` when output order matters.

## z.fn_SqlVariantToDateTime

Interprets a `sql_variant` value as a date, including the timestamp in a Schema Z bigint identifier. Partition metadata uses it to describe boundary dates.

[Source](../../modules/1010%20Functions/z.fn_SqlVariantToDateTime.sql)

```sql
create or alter function z.fn_SqlVariantToDateTime
(
	@value sql_variant
)
returns table
```

Returns one row with the original `BaseDataType` and converted `Value`. A bigint is decoded as a Schema Z identifier; a uniqueidentifier returns a NULL date; other types are converted when possible. Intermediate arithmetic can overflow.

## z.fn_ZSequenceIDToDatetime

Reads just the timestamp from a Schema Z bigint identifier. Use `z.fn_DecodeZSequenceID` when you also need the sequence component.

[Source](../../modules/1010%20Functions/z.fn_ZSequenceIDToDatetime.sql)

```sql
create or alter function z.fn_ZSequenceIDToDatetime(@SequenceID bigint)
returns datetime
```

Returns a `datetime`, ignoring the identifier's sequence component. It decodes the supplied value without checking whether it is a genuine Schema Z identifier.

## z.fn_GetSetting

Returns a database-local setting as nvarchar(max), or null when missing. Accepts only @Name; see [settings](settings.md#zfn_getsetting) for the declaration and behavior.

## z.fn_StandardizeFileName

Makes a name suitable for use as a filename component. Backup, restore and cleanup use this shared transformation to agree on names.

[Source](../../modules/1010%20Functions/z.fn_StandardizeFileName.sql)

```sql
select z.fn_StandardizeFileName(N'Sales / West'); -- Sales___West
```

Accepts and returns nvarchar(max). NULL stays NULL. Replaces filename-unsafe
characters (`<>:"/\|?*`), spaces and ASCII control characters 1–31 with underscores.
A final period becomes an underscore. Unicode and case are preserved. This is a
shared filename-component transformation used by backup, restore and cleanup;
it does not rename SQL databases or logical files or validate directory access.
