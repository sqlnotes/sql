# Trace troubleshooting

[Subsystem](readme.md) | [Object reference](reference/readme.md)

## Diagnose current behavior

TraceID identifies a logical definition. Inspect NativeTraceID in z.v_TraceOwned or the physical mapping for native operations. Before Collect, no native trace exists; a logical Running status in Building means enabled. Collect requires enabled definitions with events and freezes the run. Configure/start/collect on one dedicated connection and database.

An idle Building run is preserved while its original owner exists. An abandoned Collecting run is eligible when its owner has no active request; run cleanup from a separate privileged connection. Native generation mismatches remain registered for manual review. Different sessions can use identical logical names independently.

Callback failure rolls back the current batch; prior commits survive. Native expiry/EOF supplies periodic temp-buffer processing while overlapping generations capture. SQL and callback errors propagate, but the generated loop adds no custom completeness errors. Expiry scheduling, blocking reads and slow callbacks can exceed time budgets. Snapshot callbacks observe current sessions when their buffer is processed. Finite native buffers and processing that exhausts overlap can still lose events; successful return and zero native drops are not completeness proofs.

When its baseline is eligible, the physical-mapping definition upgrades the original single-generation primary key while preserving rows. Other existing table shapes are not reconciled; those require a fresh installation or an explicit schema transition. Collect no longer accepts TraceName/TraceID selectors.

## Permission and partial-operation failures

System supplies z.SeqGeneralID, ID/date helpers, z.usp_ForceNamingConvention, and PS_SchemaZPartitionGeneric. SQL Trace system catalogs and sp_trace_* procedures are required.

Read the relevant callable reference before retrying a failed write. Some procedures roll back any open transaction, including a caller's transaction; others leave earlier operations committed. Native server resources and filesystem actions do not share a single database rollback boundary. Catalog/DMV access is evaluated on the deployed server and depends on SQL Server version and caller context.

## Verification limits

These pages describe source behavior. A successful installation or module compilation does not demonstrate successful mail delivery, backup restoration, SQL Agent execution, trace workload collection, security migration, or application-specific Broker delivery.
