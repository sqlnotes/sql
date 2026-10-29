# Monitoring object index

[Subsystem](../readme.md) | [System](../../../docs/readme.md)

Exact SQL identifiers link to behavior and source. Native system dependencies are described in [architecture](../architecture.md).

| Object | Documentation | Definition |
| --- | --- | --- |
| `z.ActiveSessions` | [Reference](supporting-objects.md#zactivesessions) | [SQL](../../baseline/2020%20Tables/z.ActiveSessions.sql) |
| `z.SystemHealthEvent` | [Reference](supporting-objects.md#zsystemhealthevent) | [SQL](../../baseline/2020%20Tables/z.SystemHealthEvent.sql) |
| `z.fn_ExtractSystemHealthEvent` | [Reference](z.fn_ExtractSystemHealthEvent.md) | [SQL](../../modules/1010%20Functions/z.fn_ExtractSystemHealthEvent.sql) |
| `z.usp_CheckDatabaseMail` | [Reference](z.usp_CheckDatabaseMail.md) | [SQL](../../modules/1070%20Procedures/z.usp_CheckDatabaseMail.sql) |
| `z.usp_CollectSystemHealthEvents` | [Reference](z.usp_CollectSystemHealthEvents.md) | [SQL](../../modules/1070%20Procedures/z.usp_CollectSystemHealthEvents.sql) |
| `z.usp_TakeSnapshotActiveSessions` | [Reference](z.usp_TakeSnapshotActiveSessions.md) | [SQL](../../modules/1070%20Procedures/z.usp_TakeSnapshotActiveSessions.sql) |
| `z.v_ActiveSessions` | [Reference](supporting-objects.md#zv_activesessions) | [SQL](../../modules/1020%20Views/z.v_ActiveSessions.sql) |
| `z.v_ActiveSessionsNoPlan` | [Reference](supporting-objects.md#zv_activesessionsnoplan) | [SQL](../../modules/1020%20Views/z.v_ActiveSessionsNoPlan.sql) |
| `z.CPUMemoryStats` | [Reference](supporting-objects.md#zcpumemorystats) | [SQL](../../baseline/2020%20Tables/z.CPUMemoryStats.sql) |
| `z.usp_CollectCPUMemoryStats` | [Reference](z.usp_CollectCPUMemoryStats.md) | [SQL](../../modules/1070%20Procedures/z.usp_CollectCPUMemoryStats.sql) |
| `z.v_CPUMemoryStats` | [Reference](supporting-objects.md#zv_cpumemorystats) | [SQL](../../modules/1020%20Views/z.v_CPUMemoryStats.sql) |
| `z.v_IndexSpaceUsed` | [Reference](supporting-objects.md#zv_indexspaceused) | [SQL](../../modules/1020%20Views/z.v_IndexSpaceUsed.sql) |
| `z.v_PerformanceCounters` | [Reference](supporting-objects.md#zv_performancecounters) | [SQL](../../modules/1030%20Views/z.v_PerformanceCounters.sql) |
| `z.v_PerformanceCountersDefault` | [Reference](supporting-objects.md#zv_performancecountersdefault) | [SQL](../../modules/1030%20Views/z.v_PerformanceCountersDefault.sql) |
| `z.v_PerformanceCounterTypes` | [Reference](supporting-objects.md#zv_performancecountertypes) | [SQL](../../modules/1020%20Views/z.v_PerformanceCounterTypes.sql) |
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

| `z.usp_CreateErrorEventSession` | [Reference](extended-events.md#zusp_createerroreventsession) | [SQL](../../modules/1070%20Procedures/z.usp_CreateErrorEventSession.sql) |
| `z.usp_CreateLongRunningQueryEventSession` | [Reference](extended-events.md#zusp_createlongrunningqueryeventsession) | [SQL](../../modules/1070%20Procedures/z.usp_CreateLongRunningQueryEventSession.sql) |
| `z.usp_CollectErrorEvents` | [Reference](extended-events.md#zusp_collecterrorevents) | [SQL](../../modules/1070%20Procedures/z.usp_CollectErrorEvents.sql) |
| `z.usp_CollectLongRunningQueryEvents` | [Reference](extended-events.md#zusp_collectlongrunningqueryevents) | [SQL](../../modules/1070%20Procedures/z.usp_CollectLongRunningQueryEvents.sql) |
| `z.fn_ExtractErrorEvent` | [Reference](extended-events.md#zfn_extracterrorevent) | [SQL](../../modules/1010%20Functions/z.fn_ExtractErrorEvent.sql) |
| `z.fn_ExtractLongRunningQueryEvent` | [Reference](extended-events.md#zfn_extractlongrunningqueryevent) | [SQL](../../modules/1010%20Functions/z.fn_ExtractLongRunningQueryEvent.sql) |
| `z.ErrorEvent` | [Reference](extended-events.md#zerrorevent) | [SQL](../../baseline/2020%20Tables/z.ErrorEvent.sql) |
| `z.LongRunningQueryEvent` | [Reference](extended-events.md#zlongrunningqueryevent) | [SQL](../../baseline/2020%20Tables/z.LongRunningQueryEvent.sql) |
