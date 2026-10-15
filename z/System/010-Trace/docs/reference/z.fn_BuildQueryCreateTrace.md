# z.fn_BuildQueryCreateTrace

[Trace](../readme.md) | [Source](../../modules/1010%20Functions/z.fn_BuildQueryCreateTrace.sql)

## Purpose and behavior

Generate ordered creation, event/column, filter, and start script rows from current SQL Trace metadata. A trace without z.Trace metadata uses <TraceName>. Does not execute SQL or reproduce receiving-table/callback metadata.

## Parameters and defaults

```text
@TraceID int
```

These are the source-declared types and defaults. Table-valued-function callers must supply arguments or the `default` keyword explicitly.

## Results, permissions, and limits

Returns Ordinal and Script. Read-only; requires trace/catalog visibility. Review filter order and escaping before replay; explicit order by Ordinal is required.

## Dependencies

Direct SQL object dependencies: `z.Trace`, `z.usp_TraceAddEvents`, `z.usp_TraceAddFilter`, `z.usp_TraceCreate`, `z.usp_TraceStart`.

Native dependencies: `sys.fn_trace_geteventinfo`, `sys.fn_trace_getfilterinfo`, `sys.trace_columns`, `sys.trace_events`, `sys.traces`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
