# Partition architecture

[Guide](readme.md) · [Reference](reference/readme.md)

## Objects and dependencies

System owns shared storage: `PF_SchemaZPartitionGeneric` / `PS_SchemaZPartitionGeneric` use datetime-encoded bigint and `range left`; `PF_SchemaZPartitionGenericDateTime` / `PS_SchemaZPartitionGenericDateTime` use datetime and `range right`. Both start without boundaries on the default filegroup. Guards preserve existing definitions.

`z.PartitionedTableDataRetention` holds one policy per function. System initialization inserts missing generic policies and preserves customized rows. System supplies period/ID helpers, partition metadata and `z.usp_CopyTableSchema`. A function can affect several tables, indexes and schemes.

## Forward maintenance

Automatic maintenance uses UTC and adds only future period boundaries. A count of three in October means November, December and January. It does not backfill September/October into a populated catch-all after missed runs. For LEFT, the first recovery split preserves each scheme's original tail filegroup for switch-back; subsequent future splits use the policy filegroup.

When the last partition contains data, one transaction creates absent `<Table>_Partition_SplitHold` tables, switches the affected tails out, adds boundaries, checks their destination range, switches them back and drops the holders. LEFT uses lower-exclusive/upper-inclusive bounds; RIGHT uses lower-inclusive/upper-exclusive bounds. Rows outside the destination range cause rollback rather than redistribution.

## Expiration and compression

Each expired boundary is a separate transaction: create matching targets, switch every affected heap/clustered partition, merge the boundary and drop targets when `ArchivedSwappedPartitions = 0`. With value 1, targets remain for later processing. Existing targets cause failure even when empty. Names use `<Table>_Partition_YYYYMMDD`, or `_YYYYMMDD_HHMM` for hourly/minute policies.

`z.usp_CopyTableSchema` receives the exact source partition number and inherits placement and compression independently for every copied index. Indexes must be partition aligned. Maintenance does not change desired compression or move retained tables to other servers.

## Execution and concurrency

The maintenance executor serializes by partition function with a session application lock shared with the standalone boundary executor. Execution rejects caller transactions and implicit transactions. It regenerates metadata after each committed operation, isolates failures between functions and raises a combined error when any function fails.

`@ShowPlan = 1` inspects metadata and returns ordered SQL without executing copies or DDL. Preview is a snapshot; execution generates a fresh plan under its lock. Manual DDL outside these procedures still needs coordination. No blocker-killing service is started.

The existing job factory remains explicit. Defining or deploying it does not create or enable hourly maintenance jobs.

For RIGHT expiration, the retained upper partition is also held temporarily while empty neighbors merge. The empty destination's per-index compression is restored before switching retained rows back. Adjacent partitions with different filegroups for any index are rejected before DDL because preserving that placement would require data movement. Temporary merge holders use the _Partition_MergeHold suffix and must not already exist.
