# z.usp_TraceAddFilter

[Trace](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_TraceAddFilter.sql)

## Purpose and behavior

Find a stopped selected trace and filterable selected column. Null Value returns without a filter. Accept and/or and =, !=, <>, >, <, >=, <=, like, notlike (spaces stripped). Convert sql_variant to the trace column type and invoke sp_trace_setfilter; add the column if not already enabled. Values for max-length fields are placed in a 256-length variable.

## Parameters and defaults

```text
@TraceName varchar(128) = null,@TraceID int = null,@ColumnName varchar(128) = null,@ColumnID int = null,@LogicOperator varchar(3) = 'and', @ComparisonOperator varchar(7) = '=', @Value sql_variant
```

These are the source-declared types and defaults.

## Results, permissions, and limits

No defined result set. Requires ALTER TRACE; errors use raiserror or native failures. No explicit transaction. A filter does not start a trace.

## Dependencies

Direct SQL object dependencies: `z.usp_TraceAddColumns`, `z.v_Trace`, `z.v_TraceColumn`.

Native dependencies: `sys.fn_trace_geteventinfo`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
