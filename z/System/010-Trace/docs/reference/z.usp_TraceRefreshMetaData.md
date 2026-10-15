# z.usp_TraceRefreshMetaData

[Trace](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_TraceRefreshMetaData.sql)

## Purpose and behavior

Generate z.v_TraceMetaData (event/column capability matrix) and z.v_TraceDefinition (live trace selections/filters). Compare generated MD5 against each view Code Hash extended property; alter/add property only when hash differs. Trace post stage calls this procedure. Catch rolls back any open transaction and rethrows, though no transaction is started here.

## Parameters and defaults

None.

These are the source-declared types and defaults.

## Results, permissions, and limits

No parameters or defined result set. Requires view DDL, trace/catalog visibility and extended-property authority. Column set varies with server trace catalog.

## Dependencies

Native dependencies: `sys.fn_listextendedproperty`, `sys.fn_trace_geteventinfo`, `sys.fn_trace_getfilterinfo`, `sys.sp_addextendedproperty`, `sys.sp_dropextendedproperty`, `sys.trace_categories`, `sys.trace_columns`, `sys.trace_event_bindings`, `sys.trace_events`, `sys.traces`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
