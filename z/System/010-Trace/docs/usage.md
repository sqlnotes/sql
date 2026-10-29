# Trace usage

[Subsystem](readme.md) | [Object reference](reference/readme.md)

## Examples

Execute against a database containing System and this subsystem. Examples describe current interfaces; environment permissions and data determine results.

```sql
select TraceID, Name, IsEnabled, State, NativeTraceID, ReceivingTable
from z.v_TraceOwned;
```

Build all logical definitions and collect on one dedicated connection. Start only enables each logical definition. Collect freezes the run and uses overlapping physical generations for all enabled definitions; one receiving connection processes their temp buffers and other sessions remain independent. Diagnostic presets and daily reports belong to [Monitoring](../../020-Monitoring/docs/usage.md). Use the bounded custom example below during development.

## Bounded custom trace

Run all statements on one connection. This example builds and enables a logical definition, then creates its physical trace during collection. Normal completion removes the run configuration and retains destination data. Review privileges and workload impact first.

```sql
declare @TraceID int;
exec z.usp_TraceCreate @TraceName = N'DeveloperTrace', @Description = N'Bounded example', @TraceID = @TraceID output;
exec z.usp_TraceAddEvents @TraceID = @TraceID, @EventList = N'SQL:BatchCompleted', @EventColumnList = N'TextData,StartTime,Duration,SPID';
exec z.usp_TraceStart @TraceID = @TraceID;
exec z.usp_TraceCollectAndClose @MaxDurationInSec = 30, @TransactionDurationInSec = 2, @MaxEventsPerTransaction = 300;
```

On failure, inspect the owned registry and [cleanup procedure](reference/z.usp_TraceCleanupCollectors.md). An idle Building run is preserved while its original session exists. After a Collecting owner has no active request, a separate privileged connection can reap its registered native generation. The owner session itself cannot reap its own run while its cleanup request is active.

## Explicit event and column selectors

Pass complete comma-separated catalog names to the event/column procedures. For example:

```sql
exec z.usp_TraceAddEvents @TraceName = N'DeveloperTrace',
    @EventList = N'SQL:BatchCompleted,RPC:Completed',
    @EventColumnList = N'TextData,StartTime,Duration,SPID';
```

Resolve the names from `z.v_TraceEvent` and `z.v_TraceColumn` before calling. Lists trim spaces, deduplicate names and reject unknown or empty entries. Partial names, wildcard patterns and SQL query text are invalid. Column lists and RemoveEvents support the whole value `all`; AddEvents requires explicit event names. AddEvents with a NULL column list inherits existing selected columns and always includes SPID. The former query-text parameters are removed; update positional callers to the current signatures.
Use one dedicated connection and database for a collector run. TraceCreate registers the UUID automatically; normal configuration and lifecycle operations stay on that owner connection. Do not set the reserved Schema z.TraceCollector.UUID context key read-only.

## Logical routing and callbacks

Create and enable additional logical definitions before the same Collect call to merge them. Each definition keeps independent filters, destination and callbacks. Each matching delivery gets its own TraceSequence. Configure callbacks through `z.usp_TraceSetTrigger`, not direct metadata inserts. Callbacks accept named `@TraceSequence bigint`, `@TraceID int` (logical) and `@EventName nvarchar(128)` arguments. An all-event registration overrides the event-specific registration.

Use `z.fn_BuildQueryCreateTrace` with a logical ID to export its configuration, filters and callbacks. The generated native definition view still uses native IDs. The collector no longer accepts TraceName/TraceID selectors. Configuration is frozen once Collect starts; event/filter/callback configuration remains possible after logical Start while Building.

The bounded rowset backend can lose unread events even with zero native drops. Consolidation does not prove completeness. Blocking reads and callbacks can exceed collection and transaction time budgets. Separate raw saving and parsing are not implemented.
