# z.usp_TraceAddColumns

[Trace](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_TraceAddColumns.sql)

## Purpose and behavior

Change only stopped selected traces; require Name or ID. Query parameters execute caller-supplied SQL returning IDs. Comma-list names use substring LIKE matching. Add supported columns to currently selected events; column 12 is excluded from added column list. Query/list results are combined with duplicate IDs ignored. Selection query errors become explanatory throw messages. Native changes loop without an explicit transaction.

## Parameters and defaults

```text
@TraceName varchar(128) = null,@TraceID int = null,@TraceEventColumnQuery nvarchar(max) = null,@EventColumnList nvarchar(max) = null
```

These are the source-declared types and defaults.

## Results, permissions, and limits

No defined result set. Requires ALTER TRACE and permission to execute supplied query text; treat query arguments as trusted code. No selection can print a message and return.

## Dependencies

Direct SQL object dependencies: `z.v_Trace`, `z.v_TraceColumn`, `z.v_TraceEventColumn`.

Native dependencies: `sys.fn_trace_geteventinfo`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
