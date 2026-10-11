# Trace troubleshooting

[Subsystem](readme.md) | [Object reference](reference/readme.md)

## Diagnose current behavior

No active trace found means no selected Running trace is owned by the current SPID. A collector failure rolls back its current transaction and rethrows, but does not close all traces in a finally block; inspect z.v_Trace and explicitly close survivors. Configure only stopped traces. Preset long-running events contain the token SP:CompletedSP:StmtCompleted; substring lookup does not match the intended separate events. z.usp_TraceRemoveColumns does not implement all as all columns: use a query selecting ColumnID. Updating ReceivingTable on an existing stopped trace requires a non-null Description in z.usp_TraceCreate.

## Permission and partial-operation failures

System supplies z.SeqGeneralID, ID/date helpers, and z.usp_ForceNamingConvention. Partition supplies PS_SchemaZPartitionGeneric. Monitoring supplies z.v_ActiveSessions. SQL Trace system catalogs and sp_trace_* procedures are required.

Read the relevant callable reference before retrying a failed write. Some procedures roll back any open transaction, including a caller's transaction; others leave earlier operations committed. Native server resources and filesystem actions do not share a single database rollback boundary. Catalog/DMV access is evaluated on the deployed server and depends on SQL Server version and caller context.

## Verification limits

These pages describe source behavior. A successful installation or module compilation does not demonstrate successful mail delivery, backup restoration, SQL Agent execution, trace workload collection, security migration, or application-specific Broker delivery.
