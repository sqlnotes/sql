# Using Partition

[Guide](readme.md) · [Reference](reference/readme.md)

## Inspect policy

```sql
select *
from z.PartitionedTableDataRetention
where PartitionFunctionName = N'PF_SchemaZPartitionGeneric';
```

Shipped initialization uses monthly intervals, three forward periods, six retained periods and archive disabled. Table defaults instead use 12 retained periods and archive enabled. Root post can overwrite generic-policy edits.

## Preview boundaries

```sql
select Ordinal, Date, SQL
from z.fn_BuildQueryCreatePartitionForDateRange(
	null, N'PF_SchemaZPartitionGeneric', 'Monthly', 1,
	'2026-10-01', null, 3, N'Default')
order by Ordinal;
```

This returns SQL without executing it. Both endpoints are included, so three increments can generate four boundaries. Validation errors are returned as SQL containing `raiserror`, not thrown by the preview.

## Preview retention at a fixed time

```sql
select f.Ordinal, f.Name, f.SQL
from z.PartitionedTableDataRetention p
	cross apply z.fn_BuildQueryForcePartitionRetentionPolicy(
		p.PartitionFunctionName, p.PartitionRangeType,
		p.PartitionRangeTypeInterval, p.ForwardedPartitionCount,
		p.NextPartitionFileGroup, p.PartitionsToKeep,
		p.ArchivedSwappedPartitions, '2026-10-01') f
where p.PartitionFunctionName = N'PF_SchemaZPartitionGeneric'
order by f.Ordinal;
```

Review every table, switch and merge. Archive disabled means the switched table is dropped and its data removed.

## Execute after review

`z.usp_CreatePartitionForDateRange` has the builder's parameters/defaults. `z.usp_ForcePartitionRetentionPolicy` takes no parameters and applies all policies. These are execution interfaces, not previews. See [transactions and permissions](reference/readme.md).
