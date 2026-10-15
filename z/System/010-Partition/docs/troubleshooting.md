# Partition troubleshooting

[Guide](readme.md) · [Reference and source](reference/readme.md)

## Invalid policies

Use positive period intervals, nonnegative forward counts and `PartitionsToKeep >= -1`. Value -1 disables expiration; zero retains the current-period cutoff behavior. Minute, Hourly, Daily, Weekly, Monthly and Yearly are supported. Weekly starts Monday in UTC independently of DATEFIRST. Date keys cannot represent subday boundaries, so Hourly/Minute policies are rejected for that key type. Keep date spans within the supported key type and arithmetic range.

## Existing targets

A switch-out or split-holding table must not exist, even if empty. The manager fails rather than replacing it. Inspect existing retained tables before changing policy or retrying. Target names must fit SQL Server identifier limits.

## Populated catch-all

Missed periods remain combined. Recovery adds future boundaries after the current period and temporarily switches the last partition aside. All held rows must fit the first newly bounded partition; future-dated rows outside that range cause the transaction to roll back. No historical backfill or row redistribution is attempted.

## Switch failures and topology

All tables and indexes affected by the function must satisfy alignment and SQL Server switch requirements. The existing schema-copy procedure preserves each index's selected-partition compression and filegroup but does not copy foreign keys or CHECK constraints. Unsupported dependencies are rejected or cause transactional rollback. Inspect the ordered preview and engine error.

## Transactions, locking and failures

Execute with no caller transaction and implicit_transactions off. A competing maintenance session causes a lock error; no blocking session is killed. Recovery and each expired boundary commit separately. Earlier successful operations remain committed when a later operation fails. Other functions can still complete, followed by an overall failure report.

Preview does not reserve a plan for future execution. Explicitly create/enable the maintenance job through the job factory; deployment only defines it. Initialization preserves customized policies rather than restoring shipped values.

For RIGHT expiration, the retained upper partition is also held temporarily while empty neighbors merge. The empty destination's per-index compression is restored before switching retained rows back. Adjacent partitions with different filegroups for any index are rejected before DDL because preserving that placement would require data movement. Temporary merge holders use the _Partition_MergeHold suffix and must not already exist.
