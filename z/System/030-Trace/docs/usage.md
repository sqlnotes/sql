# Trace usage

[Subsystem](readme.md) | [Object reference](reference/readme.md)

## Examples

Execute against a database containing System and this subsystem. Examples describe current interfaces; environment permissions and data determine results.

```sql
select TraceID, Name, Status, CreatorSessionID, ReceivingTable
from z.v_Trace;

select * from z.fn_TraceLongRunningQueryByDay(7);
```

The implementation uses SQL Trace, including sp_trace_getdata, rather than Extended Events. Collection is synchronous and bound to the session that created the trace. Configure, start, and collect on that same connection. The default preset collector can run indefinitely in operational terms; use the bounded custom example below during development.

## Bounded custom trace

Run all statements on one connection. This example creates/starts a native trace, stores event data, and closes it on normal completion. Review privileges and workload impact first.

```sql
declare @TraceID int;
exec z.usp_TraceCreate @TraceName = N'DeveloperTrace', @Description = N'Bounded example', @TraceID = @TraceID output;
exec z.usp_TraceAddEvents @TraceID = @TraceID, @EventList = N'SQL:BatchCompleted', @EventColumnList = N'TextData,StartTime,Duration,SPID';
exec z.usp_TraceStart @TraceID = @TraceID;
exec z.usp_TraceCollectAndClose @TraceID = @TraceID, @MaxDurationInSec = 30, @TransactionDurationInSec = 3;
```

On failure, inspect [lifecycle procedures](reference/z.usp_TraceClose.md) and close surviving traces explicitly.
