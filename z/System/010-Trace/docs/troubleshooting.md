# Trace troubleshooting

[Subsystem](readme.md) | [Object reference](reference/readme.md)

## Diagnose current behavior

TraceID identifies a logical definition. Inspect NativeTraceID in z.v_TraceOwned or the physical mapping for native operations. Before Collect, no native trace exists; a logical Running status in Building means enabled. Collect requires enabled definitions with events and freezes the run. Configure/start/collect on one dedicated connection and database.

An idle Building run is preserved while its original owner exists. An abandoned Collecting run is eligible when its owner has no active request; run cleanup from a separate privileged connection. Native generation mismatches remain registered for manual review. Different sessions can use identical logical names independently.

Callback failure rolls back the current batch; prior commits survive. One-frame bounded reads can lose unread events with zero native drops. The collector does not poll native counters or raise its own exceptions for dropped or missing events. Genuine SQL/API and callback errors still propagate; successful return does not prove completeness. Blocking reads and slow callbacks can exceed time budgets. Separate raw saving and parsing are not implemented.

This initial redesign has no migration: guarded baselines do not update existing table shapes. Install fresh or explicitly recreate the development schema. Collect no longer accepts TraceName/TraceID selectors.

## Permission and partial-operation failures

System supplies z.SeqGeneralID, ID/date helpers, z.usp_ForceNamingConvention, and PS_SchemaZPartitionGeneric. SQL Trace system catalogs and sp_trace_* procedures are required.

Read the relevant callable reference before retrying a failed write. Some procedures roll back any open transaction, including a caller's transaction; others leave earlier operations committed. Native server resources and filesystem actions do not share a single database rollback boundary. Catalog/DMV access is evaluated on the deployed server and depends on SQL Server version and caller context.

## Verification limits

These pages describe source behavior. A successful installation or module compilation does not demonstrate successful mail delivery, backup restoration, SQL Agent execution, trace workload collection, security migration, or application-specific Broker delivery.
