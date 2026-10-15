# z.usp_TraceRemoveEvents

[Trace](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_TraceRemoveEvents.sql)

## Purpose and behavior

Change only stopped selected traces; require Name or ID. Query parameters execute caller-supplied SQL returning IDs. Comma-list names use substring LIKE matching. Remove selected events; EventList=All selects all catalog events. Query/list results are combined with duplicate IDs ignored. Selection query errors become explanatory raiserror messages. Native changes loop without an explicit transaction.

## Parameters and defaults

```text
@TraceName varchar(128) = null,@TraceID int = null,@TraceEventQuery nvarchar(max) = null,@EventList nvarchar(max) = null
```

These are the source-declared types and defaults.

## Results, permissions, and limits

No defined result set. Requires ALTER TRACE and permission to execute supplied query text; treat query arguments as trusted code. No selection can print a message and return.

## Dependencies

Direct SQL object dependencies: `z.v_Trace`, `z.v_TraceEvent`.

Native dependencies: `sys.fn_trace_geteventinfo`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
