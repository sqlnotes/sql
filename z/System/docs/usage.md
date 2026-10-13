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
	@FullSourceTableName = N'z.DatabaseSchemas',
	@FullTargetTableName = N'dbo.DatabaseSchemasCopy',
	@PartitionNumber = 1,
	@ShowPlan = 1;
```

This returns ordered `Ordinal`, `PartName` and `Definition` rows without creating a table or executing any returned SQL. With storage and compression overrides omitted, it inherits each source heap/index's settings; a partitioned source uses the selected partition, defaulting to partition 1. Normal targets are nonpartitioned. [Review copy limitations](reference/schema-copy.md). The executing procedure protects an existing target by default; replacement requires an explicit request. `@PrintCode = 1` prints and executes in normal mode; use `@ShowPlan = 1` for preview.

## Print initialization SQL

```sql
exec z.usp_DataInitializationHelper
	@FullObjectName = N'z.DatabaseSchemas',
	@ForceMatchedDataUpdate = 0;
```

This prints a script based on current rows, without executing its merge. Output can contain sensitive data.

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
