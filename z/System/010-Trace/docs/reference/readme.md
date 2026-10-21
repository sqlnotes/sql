# Trace object index

[Subsystem](../readme.md) | [System](../../../docs/readme.md)

Exact SQL identifiers link to behavior and source. Native system dependencies are described in [architecture](../architecture.md).

| Object | Documentation | Definition |
| --- | --- | --- |
| `z.TraceTrigger` | [Reference](supporting-objects.md#ztracetrigger) | [SQL](../../baseline/2020%20Tables/z.TraceTrigger.sql) |
| `z.Trace` | [Reference](supporting-objects.md#ztrace) | [SQL](../../baseline/2020%20Tables/z.Trace.sql) |
| `z.fn_BuildQueryCreateTrace` | [Reference](z.fn_BuildQueryCreateTrace.md) | [SQL](../../modules/1010%20Functions/z.fn_BuildQueryCreateTrace.sql) |
| `z.usp_TraceAddColumns` | [Reference](z.usp_TraceAddColumns.md) | [SQL](../../modules/1070%20Procedures/z.usp_TraceAddColumns.sql) |
| `z.usp_TraceAddEvents` | [Reference](z.usp_TraceAddEvents.md) | [SQL](../../modules/1070%20Procedures/z.usp_TraceAddEvents.sql) |
| `z.usp_TraceAddFilter` | [Reference](z.usp_TraceAddFilter.md) | [SQL](../../modules/1070%20Procedures/z.usp_TraceAddFilter.sql) |
| `z.usp_TraceClose` | [Reference](z.usp_TraceClose.md) | [SQL](../../modules/1070%20Procedures/z.usp_TraceClose.sql) |
| `z.usp_TraceCollectAndClose` | [Reference](z.usp_TraceCollectAndClose.md) | [SQL](../../modules/1070%20Procedures/z.usp_TraceCollectAndClose.sql) |
| `z.usp_TraceCreate` | [Reference](z.usp_TraceCreate.md) | [SQL](../../modules/1070%20Procedures/z.usp_TraceCreate.sql) |
| `z.usp_TraceRefreshMetaData` | [Reference](z.usp_TraceRefreshMetaData.md) | [SQL](../../modules/1070%20Procedures/z.usp_TraceRefreshMetaData.sql) |
| `z.usp_TraceRemoveColumns` | [Reference](z.usp_TraceRemoveColumns.md) | [SQL](../../modules/1070%20Procedures/z.usp_TraceRemoveColumns.sql) |
| `z.usp_TraceRemoveEvents` | [Reference](z.usp_TraceRemoveEvents.md) | [SQL](../../modules/1070%20Procedures/z.usp_TraceRemoveEvents.sql) |
| `z.usp_TraceStart` | [Reference](z.usp_TraceStart.md) | [SQL](../../modules/1070%20Procedures/z.usp_TraceStart.sql) |
| `z.usp_TraceStop` | [Reference](z.usp_TraceStop.md) | [SQL](../../modules/1070%20Procedures/z.usp_TraceStop.sql) |
| `z.v_TraceColumn` | [Reference](supporting-objects.md#zv_tracecolumn) | [SQL](../../modules/1020%20Views/z.v_TraceColumn.sql) |
| `z.v_TraceDefinition` | [Generated view](supporting-objects.md#zv_tracedefinition) | [Generator](z.usp_TraceRefreshMetaData.md) |
| `z.v_TraceEventColumn` | [Reference](supporting-objects.md#zv_traceeventcolumn) | [SQL](../../modules/1020%20Views/z.v_TraceEventColumn.sql) |
| `z.v_TraceEvent` | [Reference](supporting-objects.md#zv_traceevent) | [SQL](../../modules/1020%20Views/z.v_TraceEvent.sql) |
| `z.v_TraceMetaData` | [Generated view](supporting-objects.md#zv_tracemetadata) | [Generator](z.usp_TraceRefreshMetaData.md) |
| `z.v_Trace` | [Reference](supporting-objects.md#zv_trace) | [SQL](../../modules/1020%20Views/z.v_Trace.sql) |
| `z.usp_TraceAssertOwner` | [Reference](z.usp_TraceAssertOwner.md) | [SQL](../../modules/1070%20Procedures/z.usp_TraceAssertOwner.sql) |
| `z.usp_TraceCleanupCollectors` | [Reference](z.usp_TraceCleanupCollectors.md) | [SQL](../../modules/1070%20Procedures/z.usp_TraceCleanupCollectors.sql) |
| `z.usp_TraceRegisterCollector` | [Reference](z.usp_TraceRegisterCollector.md) | [SQL](../../modules/1070%20Procedures/z.usp_TraceRegisterCollector.sql) |
| `z.usp_TraceReleaseCollector` | [Reference](z.usp_TraceReleaseCollector.md) | [SQL](../../modules/1070%20Procedures/z.usp_TraceReleaseCollector.sql) |
| `z.TraceCollector` | [Reference](supporting-objects.md#ztracecollector-and-ztracecollectortrace) | [SQL](../../baseline/2020%20Tables/z.TraceCollector.sql) |
| `z.TraceCollectorTrace` | [Reference](supporting-objects.md#ztracecollector-and-ztracecollectortrace) | [SQL](../../baseline/2020%20Tables/z.TraceCollectorTrace.sql) |
| `z.v_TraceOwned` | [Reference](supporting-objects.md#zv_traceowned) | [SQL](../../modules/1020%20Views/z.v_TraceOwned.sql) |
| `z.TraceEvent` | [Reference](supporting-objects.md#ztraceevent) | [SQL](../../baseline/2020%20Tables/z.TraceEvent.sql) |
| `z.TraceEventColumn` | [Reference](supporting-objects.md#ztraceeventcolumn) | [SQL](../../baseline/2020%20Tables/z.TraceEventColumn.sql) |
| `z.TraceFilter` | [Reference](supporting-objects.md#ztracefilter) | [SQL](../../baseline/2020%20Tables/z.TraceFilter.sql) |
| `z.usp_TraceSetTrigger` | [Reference](z.usp_TraceSetTrigger.md) | [SQL](../../modules/1070%20Procedures/z.usp_TraceSetTrigger.sql) |
| `z.usp_TraceRemoveTrigger` | [Reference](z.usp_TraceRemoveTrigger.md) | [SQL](../../modules/1070%20Procedures/z.usp_TraceRemoveTrigger.sql) |
| `z.usp_TraceOpenPhysical` | [Reference](z.usp_TraceOpenPhysical.md) | [SQL](../../modules/1070%20Procedures/z.usp_TraceOpenPhysical.sql) |
