# Monitoring troubleshooting

[Subsystem](readme.md) | [Object reference](reference/readme.md)

## Diagnose current behavior

Empty request snapshots can be normal: the collector excludes its own session. Check DMV visibility before assuming there are no other requests. Missing ring-buffer events can mean system_health is absent, has no ring-buffer target, or has already overwritten events. Persisted duplicate keys can occur under concurrent collectors; the System Health insert uses a not-exists predicate without serialization. z.v_IndexSpaceUsage uses 8.192 / 1024 per page for columns labelled MB, rather than the usual 8 / 1024; use raw page counts when exact units matter.

## Permission and partial-operation failures

System supplies z.SeqGeneralID and PS_SchemaZPartitionGeneric. Server DMVs, Extended Events, and msdb Database Mail supply external data. System orchestration can schedule collection through Jobs.

Read the relevant callable reference before retrying a failed write. Some procedures roll back any open transaction, including a caller's transaction; others leave earlier operations committed. Native server resources and filesystem actions do not share a single database rollback boundary. Catalog/DMV access is evaluated on the deployed server and depends on SQL Server version and caller context.

## Verification limits

These pages describe source behavior. A successful installation or module compilation does not demonstrate successful mail delivery, backup restoration, SQL Agent execution, trace workload collection, security migration, or application-specific Broker delivery.
