# Trace object index

[Subsystem](../readme.md) | [System](../../../docs/readme.md)

Exact SQL identifiers link to behavior and source. Native system dependencies are described in [architecture](../architecture.md).

| Object | Documentation | Definition |
| --- | --- | --- |
| `z.TraceBlockedProcessReportActiveSessions` | [Reference](supporting-objects.md#ztraceblockedprocessreportactivesessions) | [SQL](../../baseline/2020%20Tables/z.TraceBlockedProcessReportActiveSessions.sql) |
| `z.TraceBlockedProcessReport` | [Reference](supporting-objects.md#ztraceblockedprocessreport) | [SQL](../../baseline/2020%20Tables/z.TraceBlockedProcessReport.sql) |
| `z.TraceError` | [Reference](supporting-objects.md#ztraceerror) | [SQL](../../baseline/2020%20Tables/z.TraceError.sql) |
| `z.TraceFileAutoGrowActiveSessions` | [Reference](supporting-objects.md#ztracefileautogrowactivesessions) | [SQL](../../baseline/2020%20Tables/z.TraceFileAutoGrowActiveSessions.sql) |
| `z.TraceFileAutoGrow` | [Reference](supporting-objects.md#ztracefileautogrow) | [SQL](../../baseline/2020%20Tables/z.TraceFileAutoGrow.sql) |
| `z.TraceLongRunningQuery` | [Reference](supporting-objects.md#ztracelongrunningquery) | [SQL](../../baseline/2020%20Tables/z.TraceLongRunningQuery.sql) |
| `z.TraceTrigger` | [Reference](supporting-objects.md#ztracetrigger) | [SQL](../../baseline/2020%20Tables/z.TraceTrigger.sql) |
| `z.Trace` | [Reference](supporting-objects.md#ztrace) | [SQL](../../baseline/2020%20Tables/z.Trace.sql) |
| `z.fn_BuildQueryCreateTrace` | [Reference](z.fn_BuildQueryCreateTrace.md) | [SQL](../../modules/1010%20Functions/z.fn_BuildQueryCreateTrace.sql) |
| `z.fn_TraceLongRunningQueryByDay` | [Reference](z.fn_TraceLongRunningQueryByDay.md) | [SQL](../../modules/1030%20Functions/z.fn_TraceLongRunningQueryByDay.sql) |
| `z.usp_CollectTrace` | [Reference](z.usp_CollectTrace.md) | [SQL](../../modules/1070%20Procedures/z.usp_CollectTrace.sql) |
| `z.usp_TakeSnapshotActiveSessionsForBlockedProcessReport` | [Reference](z.usp_TakeSnapshotActiveSessionsForBlockedProcessReport.md) | [SQL](../../modules/1070%20Procedures/z.usp_TakeSnapshotActiveSessionsForBlockedProcessReport.sql) |
| `z.usp_TakeSnapshotActiveSessionsForFileAutoGrow` | [Reference](z.usp_TakeSnapshotActiveSessionsForFileAutoGrow.md) | [SQL](../../modules/1070%20Procedures/z.usp_TakeSnapshotActiveSessionsForFileAutoGrow.sql) |
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
