# Partition retention reference

[Object index](readme.md)

## z.fn_BuildQueryForcePartitionRetentionPolicy

[Source](../../modules/1030%20Functions/z.fn_BuildQueryForceRetentionPolicy.sql)

```sql
create or alter function z.fn_BuildQueryForcePartitionRetentionPolicy
(
	@PartitionFunctionName nvarchar(128),
	@PartitionRangeType varchar(20),
	@PartitionRangeTypeInterval int,
	@ForwardedPartitionCount int,
	@NextPartitionFileGroup nvarchar(128),
	@PartitionsToKeep int,
	@ArchivedSwappedPartitions bit,
	@Today datetime = null
)
```

Returns the retained `Ordinal`, `Name`, `SQL` columns plus `Action`, `TableName` and `PartitionNumber`. A row represents an atomic action affecting all tables sharing the function; TableName can be null for a grouped action. Error rows contain executable error text. Selecting the function does not execute copies or DDL. Today defaults to UTC. Review error rows first; execute action rows in Ordinal order through EXEC sys.sp_executesql with no caller transaction.

A positive interval and nonnegative forward count are required. Forward count means future boundaries: October with count 3 adds November, December, January, skipping existing values and anything at/below the maximum existing boundary. Missing historical periods remain combined. Date keys require Daily or coarser periods; Hourly/Minute policies are rejected.

PartitionsToKeep = -1 disables expiration. Nonnegative values select boundaries at/before current period start minus count times interval; values below -1 are invalid. Datetime2 boundary precision is retained. The preceding partition is switched out for each selected boundary, highest ordinal first.

## z.usp_ForcePartitionRetentionPolicy

[Source](../../modules/1070%20Procedures/z.usp_ForcePartitionRetentionPolicy.sql)

```sql
create or alter procedure z.usp_ForcePartitionRetentionPolicy
(
	@PartitionFunctionName nvarchar(128) = null,
	@ShowPlan bit = 0
)
```

No arguments applies all policy rows. A function selector requires a matching policy. ShowPlan returns `PartitionFunctionName`, `Ordinal`, `Action`, `TableName`, `PartitionNumber`, `SQL` in function/ordinal order. Preview performs metadata checks without executing copies or DDL; source schema-copy capability is validated additionally during execution. Preview can be captured with INSERT EXEC and does not start an implicit transaction.

Execution requires no caller transaction and implicit_transactions off. Each function is serialized by a session application lock. Execution checks that each action changes the boundary count and stops with an error if no progress is made. Generated actions are regenerated after each commit, so merges cannot leave stale partition numbers for later actions. Each recovery and expired boundary is one transaction across every affected table. A failure rolls back that action, releases its lock, continues other functions, and raises a combined failure at the end.

## Recovery, expiration and compression

Recovery creates absent `<Table>_Partition_SplitHold` holders using the exact last partition number. It switches tails out, splits future boundaries, adds trusted source/range CHECKs, switches back and removes holders. LEFT ranges use `> lower and <= upper`; RIGHT uses `>= lower and < upper`, with special handling for no lower boundary and NULL. Rows spanning more than the one destination range cause rollback, without redistribution. For LEFT, the first recovery split uses each scheme's original tail filegroup; subsequent splits use the policy filegroup.

Expiration creates same-schema `<Table>_Partition_YYYYMMDD`, or `_YYYYMMDD_HHMM` for Minute/Hourly. The suffix identifies the removed upper boundary rather than a month label. Any existing target is an error. It switches all affected heaps/clustered tables before merging the boundary. ArchivedSwappedPartitions = 1 retains targets; value 0 drops them within the transaction. No archive transport or direct-truncate shortcut is performed.

`z.usp_CopyTableSchema` remains the shared copy implementation. Calls pass the exact partition number and no placement/compression override, preserving each index's selected-partition storage/compression. All indexes must align on the managed function and partition column. No compression-by-age policy or populated-partition compression rebuild occurs.

Required permissions include complete metadata visibility, source/target table DDL and partition function/scheme DDL. Unsupported source features, constraints or engine switch restrictions can reject an action; inspect preview and execution errors. Manual DDL outside the shared maintenance lock still requires coordination.

For RIGHT expiration, the retained upper partition is also held temporarily while empty neighbors merge. The empty destination's per-index compression is restored before switching retained rows back. Adjacent partitions with different filegroups for any index are rejected before DDL because preserving that placement would require data movement. Temporary merge holders use the _Partition_MergeHold suffix and must not already exist.
