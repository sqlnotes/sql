# Using Partition

[Guide](readme.md) · [Reference](reference/readme.md)

## Inspect policy

```sql
select *
from z.PartitionedTableDataRetention
where PartitionFunctionName in (N'PF_SchemaZPartitionGeneric', N'PF_SchemaZPartitionGenericDateTime');
```

Missing generic policies are seeded monthly/1, three future boundaries, an expiration cutoff six intervals before the current period, and switched-table retention disabled. Existing policy values are preserved. Table defaults use a cutoff distance of 12 intervals and switched-table retention enabled.

## Preview automatic maintenance

```sql
exec z.usp_ForcePartitionRetentionPolicy
	@PartitionFunctionName = N'PF_SchemaZPartitionGeneric',
	@ShowPlan = 1;
```

The result identifies function, ordinal, action, partition number and SQL. Actions group all consumers of the function, so TableName is NULL; affected tables are listed in the SQL. Preview executes no copies or DDL. For a reproducible policy calculation, select `Ordinal`, `Name`, `SQL` from `z.fn_BuildQueryForcePartitionRetentionPolicy` with an explicit `@Today`.

## Execute a selected policy

```sql
exec z.usp_ForcePartitionRetentionPolicy
	@PartitionFunctionName = N'PF_SchemaZPartitionGeneric';
```

Omit the function selector to apply all configured policies. Execute without a caller transaction and with implicit_transactions off. Each recovery/expired-boundary operation is atomic across affected tables; later failures do not undo earlier committed operations.

`PartitionsToKeep = -1` keeps all data while continuing future-boundary maintenance. `ArchivedSwappedPartitions = 1` keeps expired partitions as same-schema tables; value 0 switches out and drops them before the transaction commits. No archive transport occurs.

## Monthly retention example

For regular monthly RIGHT boundaries with interval 1, October 2026 with `PartitionsToKeep = 1` uses September 1 as its cutoff. Data before September 1 expires; September and the current October remain. The September 1 boundary is also merged, leaving the oldest catch-all partition ending at October 1. Future boundaries are independent of the retention cutoff.

The retained table suffix identifies the removed upper boundary, not a month label: August data switched at September 1 uses `<Table>_Partition_20260901`. A catch-all can span several months, so PartitionsToKeep does not guarantee exactly that many physical partitions or months of data. Maintenance does not recreate missing historical boundaries.

## Standalone boundaries

```sql
select Ordinal, Date, SQL
from z.fn_BuildQueryCreatePartitionForDateRange(
	null, N'PF_SchemaZPartitionGeneric', 'Monthly', 1,
	'2026-11-01', '2027-01-01', null, N'Default')
order by Ordinal;
```

The procedure can also preview the same SQL, resolving the function from a table:

```sql
exec z.usp_CreatePartitionForDateRange
	@ObjectName = N'dbo.YourPartitionedTable',
	@PartitionRangeType = 'Monthly',
	@DateFrom = '2026-11-01',
	@DateTo = '2027-01-01',
	@ShowPlan = 1;
```

Review the returned Ordinal, Date and SQL rows; ShowPlan executes no generated statements. Omit ShowPlan or pass 0 to execute. Existing positional arguments retain their positions because ShowPlan is appended.

The standalone builder includes both endpoints; its count means interval increments, unlike automatic policy forward count. Validation failures return executable error text. `z.usp_CreatePartitionForDateRange` executes these statements under the maintenance lock but does not perform populated-tail recovery; use automatic maintenance for that behavior.

## Scheduling

Call the existing `z.usp_CreateAllServiceJobs` explicitly when job setup is desired. Deployment does not create or enable jobs. Review [transactions and permissions](reference/readme.md) before execution.
