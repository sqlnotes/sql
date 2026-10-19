# z.usp_TraceAddEvents

[Trace](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_TraceAddEvents.sql)

## Purpose and behavior

Change only stopped selected traces; require Name or ID. Query parameters execute caller-supplied SQL returning IDs. Comma-list names use substring LIKE matching. Select event/column bindings, inherit existing columns when EventColumnList is null, and always include SPID column 12. Query/list results are combined with duplicate IDs ignored. Selection query errors become explanatory throw messages. Native changes loop without an explicit transaction.

## Parameters and defaults

```text
@TraceName varchar(128) = null,@TraceID int = null,@TraceEventQuery nvarchar(max) = null,@EventList nvarchar(max) = null,@TraceEventColumnQuery nvarchar(max) = null,@EventColumnList nvarchar(max) = null
```

These are the source-declared types and defaults.

## Results, permissions, and limits

No defined result set. Requires ALTER TRACE and permission to execute supplied query text; treat query arguments as trusted code. No selection can print a message and return.

## Dependencies

Direct SQL object dependencies: `z.v_TraceColumn`, `z.v_TraceEvent`, `z.v_trace`.

Native dependencies: `sys.fn_trace_geteventinfo`, `sys.trace_event_bindings`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
