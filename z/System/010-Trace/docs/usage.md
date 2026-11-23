# Trace usage

[Subsystem](readme.md) | [Object reference](reference/readme.md)

Use one dedicated connection to create a trace, select the activity to capture, start it, and collect events into a table. Keep that connection open for the whole workflow. The examples below use the current database as the destination.

## Inspect traces

`z.v_Trace` shows registered traces and their status. `z.v_TraceOwned` limits the list to traces created by your current connection.

```sql
select TraceID, Name, Status, CreatorSessionID, CreatorLoginTime, ReceivingTable
from z.v_Trace;
select * from z.v_TraceOwned;
```

## Bounded custom trace

This example captures completed SQL batches, including their text, start time, duration and session ID. It excludes the connection running the trace. Collection ends after approximately 30 seconds and closes the trace; received rows remain in the default table `z.Trace_DeveloperTrace`. The duration is a processing deadline, not a strict time limit if native reads or callbacks block.

```sql
declare @TraceID int;
exec z.usp_TraceCreate @TraceName = N'DeveloperTrace', @Description = N'Example', @TraceID = @TraceID output;
exec z.usp_TraceAddEvents @TraceID = @TraceID, @EventList = N'SQL:BatchCompleted', @EventColumnList = N'TextData,StartTime,Duration,SPID,EventClass';
exec z.usp_TraceAddFilter @TraceID = @TraceID, @ColumnName = N'SPID', @ComparisonOperator = N'<>', @Value = @@spid;
exec z.usp_TraceStart @TraceID = @TraceID;
exec z.usp_TraceCollectAndClose @MaxDurationInSec = 30, @TraceID = @TraceID;
```

Create more traces before the same collection call to poll them on the same connection. Their native configuration and destinations are independent. Omit @TraceID/@TraceName to collect all running traces created by this session/login. Configure events/columns/filters before first Start. After native event binding begins, Close/Create is required to change them. Stop/Start pauses and resumes the same trace. Callbacks and destination metadata can be changed while stopped.

## Selectors and callbacks

Event and column lists contain complete comma-separated catalog names from z.v_TraceEvent and z.v_TraceColumn. Lists trim and deduplicate names and reject unknown/empty entries. AddEvents requires explicit events; column lists and RemoveEvents accept the whole value all. NULL AddEvents column list inherits existing columns; SPID is retained where supported.

Register callbacks with z.usp_TraceSetTrigger. They accept named @TraceSequence bigint, @TraceID int and @EventName nvarchar(128), execute after the insert, and must not commit or roll back the collector transaction. EventName all overrides event-specific registrations. Configure callbacks while stopped.

## Stop and cleanup

Stop/Close accept explicit native ID/name selectors, including traces created by another session when SQL permissions allow. With no selectors, they affect only traces created by the current session/login. Stop is normal termination for that trace; other traces keep collecting. Close removes configuration and the native trace, retaining destination data.

```sql
exec z.usp_TraceStop @TraceID = 42;
exec z.usp_TraceClose @TraceID = 42;
exec z.usp_TraceCleanup;
```

Cleanup requires full session visibility and only reaps framework traces whose original owner session/login is absent. Idle connected owners are preserved. See [architecture](architecture.md) for lifecycle and best-effort transport limits.
