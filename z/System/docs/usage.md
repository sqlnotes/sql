# Using System

[Guide](readme.md) · [Reference](reference/readme.md)

## Inspect columns

```sql
select SchemaName, ObjectName, ColumnName, DataType, PrimaryKeyOrder
from z.v_Objects
where SchemaName = 'z'
order by ObjectName, ColumnID;
```

Catalog visibility controls returned rows.

## Split text in order

```sql
select Ordinal, Value
from z.fn_SplitString(N'Partition,Monitoring,Trace', N',')
order by Ordinal
option(maxrecursion 0);
```

Recursive splitters can exceed the default recursion limit. Use an explicit sort for returned order.

## Generate and decode an identifier

```sql
declare @Sequence int = next value for z.SeqGeneralID;
declare @Identifier bigint = z.fn_GenerateZSequenceID(null, @Sequence);

select @Identifier Identifier, Date, Sequence
from z.fn_DecodeZSequenceID(@Identifier);
```

The ID combines UTC seconds since 1900 and a 28-bit sequence. Allocation is not transactional and may leave gaps. Cycling, cache behavior and repeat input mean uniqueness is not unconditional; enforce uniqueness where required.

## Preview a schema copy

```sql
exec z.usp_CopyTableSchema
	@FullSourceTableName = N'z.PartitionedTableDataRetention',
	@FullTargetTableName = N'dbo.PartitionedTableDataRetentionCopy',
	@PartitionNumber = 1,
	@ShowPlan = 1;
```

This returns ordered `Ordinal`, `PartName` and `Definition` rows without creating a table or executing any returned SQL. With storage and compression overrides omitted, it inherits each source heap/index's settings; a partitioned source uses the selected partition, defaulting to partition 1. Normal targets are nonpartitioned. [Review copy limitations](reference/schema-copy.md). The executing procedure protects an existing target by default; replacement requires an explicit request. `@PrintCode = 1` prints and executes in normal mode; use `@ShowPlan = 1` for preview.

## Print initialization SQL

```sql
exec z.usp_DataInitializationHelper
	@FullObjectName = N'z.PartitionedTableDataRetention',
	@ForceMatchedDataUpdate = 0;
```

This prints a script based on current rows, without executing its merge. Output can contain sensitive data.

## Preview and enforce naming conventions

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

Default ownership requires an open transaction. All callers must agree on capacity and resource. Production callers should add error handling; acquisition has no overall timeout. [Coordination details](reference/coordination.md).
