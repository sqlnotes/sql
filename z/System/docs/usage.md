# Using System

[Guide](readme.md) · [Reference](reference/readme.md)

These examples show how to use shared System helpers from your own SQL. Run them in the database where Schema Z is installed. Each section explains the result you should expect and links to further details where needed.

## Inspect columns

Use `z.v_Objects` when you need column names and types without assembling several catalog queries. This example lists columns of visible objects in schema `z`:

```sql
select SchemaName, ObjectName, ColumnName, DataType, PrimaryKeyOrder
from z.v_Objects
where SchemaName = 'z'
order by ObjectName, ColumnID;
```

Catalog visibility controls returned rows.

## Split text in order

Use `z.fn_SplitString` to turn delimited text into rows. This example returns three rows, with `Ordinal` values 1–3 and the corresponding names in `Value`:

```sql
select Ordinal, Value
from z.fn_SplitString(N'Partition,Monitoring,Trace', N',')
order by Ordinal
option(maxrecursion 0);
```

Recursive splitters can exceed the default recursion limit. Use an explicit sort for returned order.

## Generate and decode an identifier

Use a sequence value and a timestamp to create a bigint identifier that can later be decoded. The example returns the generated identifier together with its timestamp and sequence component:

```sql
declare @Sequence int = next value for z.SeqGeneralID;
declare @Identifier bigint = z.fn_GenerateZSequenceID(null, @Sequence);

select @Identifier Identifier, Date, Sequence
from z.fn_DecodeZSequenceID(@Identifier);
```

The ID combines UTC seconds since 1900 and a 28-bit sequence. Allocation is not transactional and may leave gaps. Cycling, cache behavior and repeat input mean uniqueness is not unconditional; enforce uniqueness where required.

## Preview a schema copy

Use `z.usp_CopyTableSchema` to create an empty table from an existing table's definition. Start with `@ShowPlan = 1` to inspect the statements before creating anything:

```sql
exec z.usp_CopyTableSchema
	@FullSourceTableName = N'z.PartitionedTableDataRetention',
	@FullTargetTableName = N'dbo.PartitionedTableDataRetentionCopy',
	@PartitionNumber = 1,
	@ShowPlan = 1;
```

This returns ordered `Ordinal`, `PartName` and `Definition` rows without creating a table or executing any returned SQL. With storage and compression overrides omitted, it inherits each source heap/index's settings; a partitioned source uses the selected partition, defaulting to partition 1. Normal targets are nonpartitioned. [Review copy limitations](reference/schema-copy.md). The executing procedure protects an existing target by default; replacement requires an explicit request. `@PrintCode = 1` prints and executes in normal mode; use `@ShowPlan = 1` for preview.

## Print initialization SQL

Use this helper to turn a table's current rows into a reusable initialization script. The following call prints a merge script; it does not apply the script:

```sql
exec z.usp_DataInitializationHelper
	@FullObjectName = N'z.PartitionedTableDataRetention',
	@ForceMatchedDataUpdate = 0;
```

This prints a script based on current rows, without executing its merge. Output can contain sensitive data.

## Preview and enforce naming conventions

Use `z.usp_ForceNamingConvention` to give indexes and constraints consistent names. Preview the proposed renames first:

```sql
exec z.usp_ForceNamingConvention
	@SchemaNames = N'["z"]',
	@TableNames = N'["dbo.OrderDetail","dbo.[Order]"]',
	@ShowPlan = 1;
```

This selects all tables and indexed views in `z` plus the two named `dbo` objects. Schema and table selectors form a union; duplicates are processed once. JSON arrays allow commas and Unicode in names. Table-list entries must be schema-qualified current-database names, using SQL identifier brackets where needed. Preview returns `ObjectName`, `NewName` and `ObjectType` for proposed index, PK/UQ, default and foreign-key renames. Review the rows, then repeat with `@ShowPlan = 0` to apply them. Tables and schemas keep their names.

At least one selector is required. Existing calls with `@TableName`, including the first two positional arguments, remain supported. `@IgnoreError = 1` prints rename failures and continues; selector validation errors still stop the call. Renames are not wrapped in a transaction and completed changes may persist after a failure. [Procedure reference](reference/procedures.md#zusp_forcenamingconvention).

Before deploying this change to an existing installation, capture custom `SchemaName` rows from `z.DatabaseSchemas` and update scheduled jobs or scripts to pass them as an explicit `@SchemaNames` JSON array. Deployment removes that table and its initialization procedure; its configured scope is not migrated automatically. The framework's post-script explicitly selects only `z`.

## Coordinate a transaction

Use a semaphore when several sessions share work but only a limited number should enter a particular operation at once. A capacity of 1 allows one holder at a time. Check the return value before doing the protected work:

```sql
begin tran;
declare @Slot int;
exec @Slot = z.usp_AcquireSemaphore @SemaphoreName = N'ExampleWork', @TotalCount = 1;
if @Slot > 0
begin
	-- Perform work here.
	exec z.usp_ReleaseSemaphore @SemaphoreName = N'ExampleWork';
end
commit;
```

Default ownership requires an open transaction. All callers must agree on capacity and resource. Production callers should add error handling; use `@LockTimeout` in milliseconds to bound acquisition (-1 waits indefinitely, 0 polls once). [Coordination details](reference/coordination.md).

## Store and read settings

Use z.usp_SetSetting to write a named text value and z.fn_GetSetting to read it. Missing names return null; callers convert values to their expected types. See [settings examples and installation requirements](reference/settings.md).
