# Partition retention reference

[Object index](readme.md)

Maintains a rolling set of date partitions: create future boundaries, then remove expired data or keep it in separate tables. A policy applies to the selected partition function and all tables sharing it. Preview the plan before running retention that can delete data.

## z.fn_BuildQueryForcePartitionRetentionPolicy

[Source](../../modules/1030%20Functions/z.fn_BuildQueryForceRetentionPolicy.sql)

Builds a maintenance plan from the supplied policy values without applying it. Use it to inspect a policy calculation for a chosen UTC date; normal maintenance reads policy rows through the procedure below.

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

Returns `Ordinal`, `Name`, `SQL`, `Action`, `TableName` and `PartitionNumber`. Each action covers all affected tables; `TableName` can therefore be NULL. Error rows contain executable error text. Selecting the function does not execute copies or DDL. `@Today` defaults to current UTC time; supply a date for a reproducible calculation. Review errors first and use the maintenance procedure to execute saved policies.

A positive interval and nonnegative forward count are required. Forward count means future boundaries: October with count 3 adds November, December, January, skipping existing values and anything at/below the maximum existing boundary. Missing historical periods remain combined. Date keys require Daily or coarser periods; Hourly/Minute policies are rejected.

PartitionsToKeep = -1 disables expiration. Nonnegative values select boundaries at/before current period start minus count times interval; values below -1 are invalid. Datetime2 boundary precision is retained. The preceding partition is switched out for each selected boundary, highest ordinal first.

## z.usp_ForcePartitionRetentionPolicy

[Source](../../modules/1070%20Procedures/z.usp_ForcePartitionRetentionPolicy.sql)

Applies the policy stored in `z.PartitionedTableDataRetention`. Pass `@PartitionFunctionName` for one policy, or omit it to apply all policies. Set `@ShowPlan = 1` to inspect the planned actions without changing tables or partitions.

```sql
create or alter procedure z.usp_ForcePartitionRetentionPolicy
(
	@PartitionFunctionName nvarchar(128) = null,
	@ShowPlan bit = 0
)
```

No arguments applies all policy rows. A function selector requires a matching policy. ShowPlan returns `PartitionFunctionName`, `Ordinal`, `Action`, `TableName`, `PartitionNumber`, `SQL` in function/ordinal order. Preview performs metadata checks without executing copies or DDL; source schema-copy capability is validated additionally during execution. Preview can be captured with INSERT EXEC and does not start an implicit transaction.

Execution requires no caller transaction and `implicit_transactions off`. Only one maintenance call can work on a function at a time. Each recovery or expired boundary is one transaction across every affected table. If an action fails or makes no progress, that function stops; other functions can still complete, followed by a combined error report. Earlier committed actions remain committed.

## Recovery, expiration and compression

Recovery preserves data in a populated last partition while adding future boundaries. It uses temporary `<Table>_Partition_SplitHold` tables, which must not already exist. All held rows must fit the new destination range; rows spanning several ranges cause rollback without redistribution. LEFT ranges exclude the lower bound and include the upper; RIGHT ranges include the lower and exclude the upper. For LEFT, the first recovery split retains the original tail filegroup; later splits use the policy filegroup.

Tables with CHECK constraints may need constraint revalidation during recovery or RIGHT expiration. This can scan the entire source table while schema locks are held. The procedure preserves which constraints were trusted, untrusted or disabled; existing untrusted constraints are re-enabled without validating old rows. SQL Server comparison error 8604 is handled through the same constraint-preserving retry path.

Expired rows are placed in same-schema tables named `<Table>_Partition_YYYYMMDD`, or `_YYYYMMDD_HHMM` for Minute/Hourly. The suffix identifies the removed upper boundary rather than a month label. Any existing target is an error. `@ArchivedSwappedPartitions = 1` keeps these tables; value 0 permanently deletes them and their rows within the operation's transaction. Keeping them does not copy them to another server or storage service.

`z.usp_CopyTableSchema` remains the shared copy implementation. Calls pass the exact partition number and no placement/compression override, preserving each index's selected-partition storage/compression. All indexes must align on the managed function and partition column. No compression-by-age policy or populated-partition compression rebuild occurs.

Required permissions include complete metadata visibility, source/target table DDL and partition function/scheme DDL. Unsupported source features, constraints or engine switch restrictions can reject an action; inspect preview and execution errors. Manual DDL outside the shared maintenance lock still requires coordination.

For RIGHT expiration, the retained upper partition is also held temporarily while empty neighbors merge. The empty destination's per-index compression is restored before switching retained rows back. Adjacent partitions with different filegroups for any index are rejected before DDL because preserving that placement would require data movement. Temporary merge holders use the _Partition_MergeHold suffix and must not already exist.
