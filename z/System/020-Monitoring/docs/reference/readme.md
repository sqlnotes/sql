# Monitoring object index

[Subsystem](../readme.md) | [System](../../../docs/readme.md)

Exact SQL identifiers link to behavior and source. Native system dependencies are described in [architecture](../architecture.md).

| Object | Documentation | Definition |
| --- | --- | --- |
| `z.ActiveSessions` | [Reference](supporting-objects.md#zactivesessions) | [SQL](../../baseline/2020%20Tables/z.ActiveSessions.sql) |
| `z.SystemHealthEvent` | [Reference](supporting-objects.md#zsystemhealthevent) | [SQL](../../baseline/2020%20Tables/z.SystemHealthEvent.sql) |
| `z.fn_ExtractSystemHealthEvent` | [Reference](z.fn_ExtractSystemHealthEvent.md) | [SQL](../../modules/1010%20Functions/z.fn_ExtractSystemHealthEvent.sql) |
| `z.usp_CheckDatabaseMail` | [Reference](z.usp_CheckDatabaseMail.md) | [SQL](../../modules/1070%20Procedures/z.usp_CheckDatabaseMail.sql) |
| `z.usp_CheckSystemHealthTrace` | [Reference](z.usp_CheckSystemHealthTrace.md) | [SQL](../../modules/1070%20Procedures/z.usp_CheckSystemHealthTrace.sql) |
| `z.usp_TakeSnapshotActiveSessions` | [Reference](z.usp_TakeSnapshotActiveSessions.md) | [SQL](../../modules/1070%20Procedures/z.usp_TakeSnapshotActiveSessions.sql) |
| `z.v_ActiveSessions` | [Reference](supporting-objects.md#zv_activesessions) | [SQL](../../modules/1020%20Views/z.v_ActiveSessions.sql) |
| `z.v_CPUMemoryStats` | [Reference](supporting-objects.md#zv_cpumemorystats) | [SQL](../../modules/1020%20Views/z.v_CPUMemoryStats.sql) |
| `z.v_IndexSpaceUsage` | [Reference](supporting-objects.md#zv_indexspaceusage) | [SQL](../../modules/1020%20Views/z.v_IndexSpaceUsage.sql) |
| `z.v_ObjectSpaceUsed` | [Reference](supporting-objects.md#zv_objectspaceused) | [SQL](../../modules/1020%20Views/z.v_ObjectSpaceUsed.sql) |
| `z.TraceBlockedProcessReportActiveSessions` | [Reference](supporting-objects.md#ztraceblockedprocessreportactivesessions) | [SQL](../../baseline/2020%20Tables/z.TraceBlockedProcessReportActiveSessions.sql) |
| `z.TraceBlockedProcessReport` | [Reference](supporting-objects.md#ztraceblockedprocessreport) | [SQL](../../baseline/2020%20Tables/z.TraceBlockedProcessReport.sql) |
| `z.TraceError` | [Reference](supporting-objects.md#ztraceerror) | [SQL](../../baseline/2020%20Tables/z.TraceError.sql) |
| `z.TraceFileAutoGrowActiveSessions` | [Reference](supporting-objects.md#ztracefileautogrowactivesessions) | [SQL](../../baseline/2020%20Tables/z.TraceFileAutoGrowActiveSessions.sql) |
| `z.TraceFileAutoGrow` | [Reference](supporting-objects.md#ztracefileautogrow) | [SQL](../../baseline/2020%20Tables/z.TraceFileAutoGrow.sql) |
| `z.TraceLongRunningQuery` | [Reference](supporting-objects.md#ztracelongrunningquery) | [SQL](../../baseline/2020%20Tables/z.TraceLongRunningQuery.sql) |
| `z.fn_TraceLongRunningQueryByDay` | [Reference](z.fn_TraceLongRunningQueryByDay.md) | [SQL](../../modules/1030%20Functions/z.fn_TraceLongRunningQueryByDay.sql) |
| `z.usp_CollectTrace` | [Reference](z.usp_CollectTrace.md) | [SQL](../../modules/1070%20Procedures/z.usp_CollectTrace.sql) |
| `z.usp_TakeSnapshotActiveSessionsForBlockedProcessReport` | [Reference](z.usp_TakeSnapshotActiveSessionsForBlockedProcessReport.md) | [SQL](../../modules/1070%20Procedures/z.usp_TakeSnapshotActiveSessionsForBlockedProcessReport.sql) |
| `z.usp_TakeSnapshotActiveSessionsForFileAutoGrow` | [Reference](z.usp_TakeSnapshotActiveSessionsForFileAutoGrow.md) | [SQL](../../modules/1070%20Procedures/z.usp_TakeSnapshotActiveSessionsForFileAutoGrow.sql) |
