# Partition architecture

[Guide](readme.md) · [Reference](reference/readme.md)

Partition maintenance works on a partition function and every table or index that uses it. The policy decides how far ahead to create boundaries and how far back to retain data. Preview shows the proposed changes; execution applies each recovery or expiration operation as a unit.

## Objects and dependencies

System owns shared storage: `PF_SchemaZPartitionGeneric` / `PS_SchemaZPartitionGeneric` use datetime-encoded bigint and `range left`; `PF_SchemaZPartitionGenericDateTime` / `PS_SchemaZPartitionGenericDateTime` use datetime and `range right`. Both start without boundaries on the default filegroup. Guards preserve existing definitions.

`z.PartitionedTableDataRetention` holds one policy per function. System initialization inserts missing generic policies and preserves customized rows. System supplies period/ID helpers, partition metadata and `z.usp_CopyTableSchema`. A function can affect several tables, indexes and schemes.

## Forward maintenance

Automatic maintenance uses UTC and adds only future period boundaries. A count of three in October means November, December and January. It does not backfill September/October into a populated catch-all after missed runs. For LEFT, the first recovery split preserves each scheme's original tail filegroup for switch-back; subsequent future splits use the policy filegroup.

If the last partition already contains data, maintenance temporarily holds that data while adding future boundaries. All held rows must fit the destination range; otherwise the operation rolls back rather than redistributing rows. Temporary tables use the `<Table>_Partition_SplitHold` suffix and must not already exist.

## Expiration and compression

Each expiration operation handles every affected table in one transaction. `ArchivedSwappedPartitions = 0` permanently removes the expired rows; value 1 keeps them in same-schema tables for later processing. Existing targets cause failure even when empty. Names use `<Table>_Partition_YYYYMMDD`, or `_YYYYMMDD_HHMM` for hourly/minute policies.

`z.usp_CopyTableSchema` receives the exact source partition number and inherits placement and compression independently for every copied index. Indexes must be partition aligned. Maintenance does not change desired compression or move retained tables to other servers.

## Execution and concurrency

The maintenance executor serializes by partition function with a session application lock shared with the standalone boundary executor. Execution rejects caller transactions and implicit transactions. It regenerates metadata after each committed operation, isolates failures between functions and raises a combined error when any function fails.

`@ShowPlan = 1` inspects metadata and returns ordered SQL without executing copies or DDL. Preview is a snapshot; execution generates a fresh plan under its lock. Manual DDL outside these procedures still needs coordination. No blocker-killing service is started.

System root post invokes the job factory to create or reconcile hourly general maintenance, including partition retention. Newly created jobs are enabled; existing enabled state is preserved. Installation requires Agent/msdb job and schedule permissions.

RIGHT expiration switches the retained upper partition aside during the merge, then restores its compression before switching it back. [Storage requirements](reference/retention.md#recovery-expiration-and-compression)
