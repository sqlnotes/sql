# Supporting objects and utilities

[Subsystem](../readme.md) | [Object index](readme.md)

## Access and behavior

Use the live views to inspect current requests, blocking, CPU/memory readings, counters and allocated space. Use the stored tables to investigate snapshots and events collected earlier. Each object below links to its definition for complete column types, defaults and indexes. Server and database permissions control which information is visible.

The three ActiveSessions table baselines include managed-code, transaction-version
metrics and blocker details, using BlockerSessionID consistently with the views.
Snapshot procedures populate these columns. Baselines only create missing tables;
existing table schemas are not migrated by this change. Install the updated
tables and snapshot procedures together on a fresh schema.

## z.ActiveSessions

[Source](../../baseline/2020%20Tables/z.ActiveSessions.sql)

Keeps the request snapshots saved by `z.usp_TakeSnapshotActiveSessions`, allowing later investigation after the requests finish. `SnapshotDate` is local collection time; SessionID and ActiveSessionID distinguish rows within a snapshot. Measurements retain DMV units: CPU/WaitTime/TotalElapsedTime are milliseconds, reads are counters, and GrantedMemory is pages.

The key is (SnapshotDate, SessionID, ActiveSessionID), page-compressed on `PS_SchemaZPartitionGeneric(ActiveSessionID)`. ActiveSessionID uses the shared sequence-backed ID. No foreign keys are declared.


## z.SystemHealthEvent

[Source](../../baseline/2020%20Tables/z.SystemHealthEvent.sql)

Keeps the selected `system_health` events saved by `z.usp_CollectSystemHealthEvents`. Query EventName and UTC EventDateUTC to find an event, then inspect EventBody for its full original XML and timestamp. The event key combines EventDateUTC (`datetime`), EventName (`nvarchar(128)`) and EventHash (`uniqueidentifier`); the hash comes from the XML's MD5 value. The datetime column has SQL datetime precision while the XML retains the source timestamp.

Storage is page-compressed on `PS_SchemaZPartitionGenericDateTime(EventDateUTC)`, with no foreign keys. Baseline changes do not migrate existing tables.


## z.v_ActiveSessions

[Source](../../modules/1020%20Views/z.v_ActiveSessions.sql)

Shows current requests other than the calling session, with SQL text, plans, waits, resource use and blocker details. Use it to identify long-running work and investigate who is blocking whom.

ExecutingManagedCode is the native managed-code flag. MaxVersionTraversed, AverageVersionChainTraversed and TranDurationInSecond report version-chain and elapsed-transaction measurements when a matching snapshot transaction exists; otherwise they are NULL. More than one matching transaction, blocker request or connection can produce several rows for one request.

BlockerQuery is the blocker's active batch text, or its most recent batch text when no active handle is available, including sleeping blockers. BlockerLastExecutedCommand is its last submitted command. Neither identifies the precise statement that acquired a lock or proves that the command completed. Missing or special negative blocker IDs leave blocker details NULL.

Viewing these details requires VIEW SERVER STATE on SQL Server 2019 or VIEW SERVER PERFORMANCE STATE on SQL Server 2022 and later, including access to the blocker's input buffer.

## z.v_ActiveSessionsNoPlan

[Source](../../modules/1020%20Views/z.v_ActiveSessionsNoPlan.sql)

Returns the same columns, types and order as z.v_ActiveSessions, with QueryPlan
always a typed XML NULL. The view does not call sys.dm_exec_query_plan. All other
request, transaction, blocker and input-buffer behavior and permissions are the
same as [z.v_ActiveSessions](#zv_activesessions).

## z.CPUMemoryStats

[Source](../../baseline/2020%20Tables/z.CPUMemoryStats.sql)

CPU/memory history with one stored row per local second. Columns are Date
datetime, SystemIdle int, SQLProcessUtilization int, Other int, UserModeTime
bigint, KernelModeTime bigint, PageFaults int, WorkingSetDelta bigint and
MemoryUtilizationPercentage int. Date is required; measurements are nullable.
No RecordID or SQLServerStartTime is stored.

The page-compressed primary key is Date on
PS_SchemaZPartitionGenericDateTime(Date). There is no whole-second CHECK on Date;
direct writes may contain fractional seconds. The collector truncates Date to seconds, chooses the latest
source reading within each second, updates matching rows and inserts missing
seconds. It does not generate missing observations or perform metric averaging.
See [the collector](z.usp_CollectCPUMemoryStats.md) for permissions and behavior.

## z.v_CPUMemoryStats

[Source](../../modules/1020%20Views/z.v_CPUMemoryStats.sql)

Shows recent CPU and memory observations from SQL Server's scheduler-monitor ring buffer. Results include RecordID, local Date, SystemIdle, SQLProcessUtilization, Other, UserModeTime, KernelModeTime, PageFaults, WorkingSetDelta and MemoryUtilizationPercentage. Other is the CPU percentage remaining after idle and SQL Server use; mode times use 100-nanosecond units. The buffer is temporary: use `z.usp_CollectCPUMemoryStats` to retain readings in `z.CPUMemoryStats`.

## z.v_IndexSpaceUsed

[Source](../../modules/1020%20Views/z.v_IndexSpaceUsed.sql)

Reports used, reserved and free space for each index partition, helping you compare index size and unused allocation. Returns
PartitionID, ObjectID, SchemaName, ObjectName, IndexID, IndexName,
PartitionNumber and RowCount, followed by used, reserved, free, in-row, LOB and
row-overflow page counts and corresponding sizes in KB. KB size expressions
use 8 KB per page. FreePageCount is ReservedPageCount minus UsedPageCount;
FreeSpaceKB is that difference multiplied by 8. Appended compatibility columns
Rows, SpaceUsedMB, SpaceReservedMB and FreeSpaceMB preserve the retired index-space interface.
Rows duplicates RowCount. These three MB columns retain the source expression
using 8.192 / 1024 per page; the KB columns use 8 per page. Native DMV permissions and
metadata visibility apply.

## z.v_PerformanceCounters

[Source](../../modules/1030%20Views/z.v_PerformanceCounters.sql)

Shows live SQL Server performance counters together with descriptions of their counter types. Use those descriptions to decide whether a raw value is a gauge, cumulative count, fraction or average. Returns ObjectName, CounterName, InstanceName,
CounterValue (raw bigint), CounterType (int), CounterTypeName and
CounterTypeDescription. Native fixed-width names are preserved. Unknown counter
types remain visible with null lookup fields. The lookup has one row per type.

This view does not sample, persist or calculate rates/averages. Read the type
description to determine how to interpret CounterValue. DMV permissions and
visibility still apply: VIEW SERVER STATE on SQL Server 2019, or
VIEW SERVER PERFORMANCE STATE on SQL Server 2022 and later. The view installs
after its lookup dependency.

## z.v_PerformanceCountersDefault

[Source](../../modules/1030%20Views/z.v_PerformanceCountersDefault.sql)

Selects the performance counters used by `z.usp_CollectPerformanceCounters`. It has the same seven columns and raw values as `z.v_PerformanceCounters`, narrowed to the configured categories and instances. These include Access Methods,
Availability Replica/Group, Buffer Manager/Node, Databases, General Statistics,
Latches, Locks, Memory Manager, Plan Cache, SQL Errors, SQL Statistics and
Transactions. Total-instance restrictions apply only to the categories specified
in the source; Buffer Node retains individual nodes and SQL Errors includes the
selected error categories. The literal XTP exclusions are retained. Ratio
selections include Worktables From Cache Base and Cache Hit Ratio Base for their
matching numerator counters; unrestricted availability categories retain their
base counters as well.

Object and counter names match exactly as written in the definition. A category
or instance absent on the current server contributes no rows. This view does not
collect, persist, calculate rates or guarantee row order. Apply ORDER BY in the
consuming query. Native DMV permissions and the base view's behavior apply.

## z.v_PerformanceCounterTypes

[Source](../../modules/1020%20Views/z.v_PerformanceCounterTypes.sql)

Explains how to interpret the six counter types documented for `sys.dm_os_performance_counters`. Use it when a raw counter value needs a rate, fraction or interval calculation rather than direct display. Returns CounterType int, CounterTypeName
nvarchar(64) and Description nvarchar(512). It has no DMV dependencies and
requires only access to the view. The names follow the Windows performance
counter constants used by SQL Server; the descriptions summarize raw values,
per-second rates, fractions, interval averages and base denominators.

Join CounterType to cntr_type. This view describes the type; it does not calculate
rates, choose a matching base counter or collect samples. Units remain specific
to each performance counter. For a fraction/average, match the base using the
counter's object/instance and documented base name; avoid dividing by zero.
Counter resets or server restarts require a fresh sampling interval. Use a left
join when enriching DMV rows so an unrecognized type remains visible with null
lookup fields. The catalog covers SQL Server's documented six types, rather
than all Windows performance-counter constants.

References: [SQL Server DMV counter semantics](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-os-performance-counters-transact-sql),
[counter algorithms](https://learn.microsoft.com/en-us/windows/win32/wmisdk/counter-algorithm-counter-types),
[base counter types](https://learn.microsoft.com/en-us/windows/win32/wmisdk/base-counter-types),
and [64-bit fractions and raw/base types](https://learn.microsoft.com/en-us/dotnet/api/system.diagnostics.performancedata.countertype).

## z.v_ObjectSpaceUsed

[Source](../../modules/1020%20Views/z.v_ObjectSpaceUsed.sql)

Reports how much space each object has reserved, used for data and indexes, or left unused. Results include ObjectID, SchemaName, TableName, RowCount, ReservedKB, DataKB, IndexSize and Unused. All sizes are in KB, using 8 KB per page; RowCount comes from base-index rows. Memory-optimized tables are excluded, while internal XML/spatial allocations (types 202/204) are included.

## z.TraceBlockedProcessReport

[Source](../../baseline/2020%20Tables/z.TraceBlockedProcessReport.sql)

Keeps the blocked-process events captured by the Monitoring Trace preset. Use TraceSequence to connect a report with its saved active-request snapshot in `z.TraceBlockedProcessReportActiveSessions`.

Event storage: TraceSequence bigint primary key (UTC seconds plus z.SeqGeneralID), EventID int, EventName nvarchar(128), plus nullable SQL Trace column payloads. Duration is microseconds for collected duration events; other metrics retain SQL Trace units. Page compression and PS_SchemaZPartitionGeneric(TraceSequence). No FK to trace metadata: records can remain after trace closes.


## z.TraceBlockedProcessReportActiveSessions

[Source](../../baseline/2020%20Tables/z.TraceBlockedProcessReportActiveSessions.sql)

Keeps the requests visible when the blocked-process snapshot callback ran. Join to the report on TraceSequence to investigate surrounding work; the snapshot is taken during event processing and is not a reconstruction of the event's exact moment.

Active-request snapshot correlated by TraceSequence; key (TraceSequence, SnapshotDate, SessionID, ActiveSessionID). SnapshotDate defaults local getdate; ActiveSessionID defaults UTC/sequence encoding. Page compression and PS_SchemaZPartitionGeneric(TraceSequence). Columns match Monitoring request snapshots; callbacks leave QueryPlan null. No FK to event table.


## z.TraceError

[Source](../../baseline/2020%20Tables/z.TraceError.sql)

Keeps SQL error events captured by the Monitoring Trace preset, including their available SQL Trace payloads. Query the stored events after collection to investigate errors that are no longer visible in current requests.

Event storage: TraceSequence bigint primary key (UTC seconds plus z.SeqGeneralID), EventID int, EventName nvarchar(128), plus nullable SQL Trace column payloads. Duration is microseconds for collected duration events; other metrics retain SQL Trace units. Page compression and PS_SchemaZPartitionGeneric(TraceSequence). No FK to trace metadata: records can remain after trace closes.


## z.TraceFileAutoGrow

[Source](../../baseline/2020%20Tables/z.TraceFileAutoGrow.sql)

Keeps file-growth events captured by the Monitoring Trace preset. Join TraceSequence to `z.TraceFileAutoGrowActiveSessions` when you need the related snapshot of requests running around the growth.

Event storage: TraceSequence bigint primary key (UTC seconds plus z.SeqGeneralID), EventID int, EventName nvarchar(128), plus nullable SQL Trace column payloads. Duration is microseconds for collected duration events; other metrics retain SQL Trace units. Page compression and PS_SchemaZPartitionGeneric(TraceSequence). No FK to trace metadata: records can remain after trace closes.


## z.TraceFileAutoGrowActiveSessions

[Source](../../baseline/2020%20Tables/z.TraceFileAutoGrowActiveSessions.sql)

Keeps the requests visible when a file-growth snapshot callback ran. Join to the growth event on TraceSequence. QueryPlan remains NULL, and the snapshot reflects collection time rather than an exact replay of event-time activity.

Active-request snapshot correlated by TraceSequence; key (TraceSequence, SnapshotDate, SessionID, ActiveSessionID). SnapshotDate defaults local getdate; ActiveSessionID defaults UTC/sequence encoding. Page compression and PS_SchemaZPartitionGeneric(TraceSequence). Columns match Monitoring request snapshots; callbacks leave QueryPlan null. No FK to event table.


## z.TraceLongRunningQuery

[Source](../../baseline/2020%20Tables/z.TraceLongRunningQuery.sql)

Keeps the slow-query events captured by the Monitoring Trace preset. Query individual events here or use the daily and hourly summary functions to compare their duration ranges over time.

Event storage: TraceSequence bigint primary key (UTC seconds plus z.SeqGeneralID), EventID int, EventName nvarchar(128), plus nullable SQL Trace column payloads. Duration is microseconds for collected duration events; other metrics retain SQL Trace units. Page compression and PS_SchemaZPartitionGeneric(TraceSequence). No FK to trace metadata: records can remain after trace closes.
