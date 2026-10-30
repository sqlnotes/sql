# Monitoring usage

[Subsystem](readme.md) | [Object reference](reference/readme.md)

## Examples

Execute against a database containing System and this subsystem. Examples describe current interfaces; environment permissions and data determine results.

```sql
select SessionID, BlockerSessionID, DurationInSecond, DatabaseName, SQLText
from z.v_ActiveSessions;

select ObjectID, IndexName, PartitionNumber, [RowCount], UsedSpaceKB, ReservedSpaceKB, FreeSpaceKB
from z.v_IndexSpaceUsed;

select ObjectID, SchemaName, TableName, ReservedKB, DataKB
from z.v_ObjectSpaceUsed;

exec z.usp_TakeSnapshotActiveSessions;
exec z.usp_CollectSystemHealthEvents;
```

Snapshots capture requests at collection time, not a full session history. Query text, plans, login names, and client details can be sensitive. Database Mail configuration is an administrative operation that changes server settings and msdb; it is not a health-only check.

## CPU and memory history

```sql
exec z.usp_CollectCPUMemoryStats;
select * from z.CPUMemoryStats order by Date desc;
```

Collection truncates the view's local Date to seconds. For each second, it
chooses the latest available source reading and refreshes the stored row; missing
seconds are inserted. The table does not store RecordID or server startup time. Read the
[collector reference](reference/z.usp_CollectCPUMemoryStats.md) for transaction
behavior, permissions and bounded-source limits.

## Performance counter history

```sql
exec z.usp_CollectPerformanceCounters @Interval = 1, @Duration = 60;
select Date, ObjectName, CounterName, InstanceName, CounterValue
from z.PerformanceCounters
order by Date desc, ObjectName, CounterName, InstanceName;
```

The collector persists each interval to the shared datetime partition scheme,
using UTC sample times. Gauges store the latest reading, cumulative counts become
per-second rates, and ratio/average counters use their matching bases. Raw values
and actual elapsed seconds are retained. The default duration is 2147483647
seconds; use an explicit duration for a bounded run. See the
[collector and table reference](reference/z.usp_CollectPerformanceCounters.md).

## Performance counter types

```sql
select * from z.v_PerformanceCounterTypes;

select * from z.v_PerformanceCountersDefault
order by ObjectName, CounterName, InstanceName;

select ObjectName, CounterName, InstanceName, CounterValue, CounterType,
    CounterTypeName, CounterTypeDescription
from z.v_PerformanceCounters;
```

The lookup describes raw counter interpretation. Calculating rates and averages
requires appropriate samples and matching base counters. See the
[counter-type reference](reference/supporting-objects.md#zv_performancecountertypes).

## Error and long-running query Extended Events

Read the [session, collector and table reference](reference/extended-events.md)
for permissions, preserved-existing-session behavior and ring-buffer limits.
Collectors automatically create missing sessions and start stopped ones. Server
event-session privileges are required for those operations. To prepare them
separately, call:

```sql
exec z.usp_CreateErrorEventSession;
exec z.usp_CreateLongRunningQueryEventSession;
```

Poll from the database holding the destination tables:

```sql
exec z.usp_CollectErrorEvents;
exec z.usp_CollectLongRunningQueryEvents;
select * from z.ErrorEvent;
select * from z.LongRunningQueryEvent;
```

Collectors ensure their sessions exist and run before reading; stored history is retained. Schedule polling
explicitly if required; no job is installed automatically. Ring-buffer overwrite
and XML truncation can leave gaps between polls.

## SQL Trace diagnostics

Read [the preset collector reference](reference/z.usp_CollectTrace.md) before running it: it builds/enables four logical definitions, captures their union through overlapping physical rowset generations with one receiving connection, and enters synchronous collection with a long default duration. Configure and collect on the same connection. For a bounded custom trace, see [Trace usage](../../010-Trace/docs/usage.md#bounded-custom-trace).

Read retained daily summaries without starting collection:

```sql
select * from z.fn_TraceLongRunningQueryByDay(7);
```

Collector failures may leave owned native resources open; inspect `z.v_Trace` using NativeTraceID and run generation-safe framework cleanup from a separate privileged connection when eligible. Idle Building configuration is preserved; abandoned Collecting configuration is eligible when its owner has no active request. Native zero-drop counters do not establish complete reception.