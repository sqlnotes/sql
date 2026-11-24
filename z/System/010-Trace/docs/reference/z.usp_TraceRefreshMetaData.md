# z.usp_TraceRefreshMetaData

[Trace](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_TraceRefreshMetaData.sql)

## Purpose and behavior

Updates the generated views used to inspect available trace columns and live trace configuration. Run it when those views need to reflect the server's trace catalog; deployment runs it during Trace's post stage. Unchanged definitions are left in place.

`z.v_TraceMetaData` shows which columns each event supports. `z.v_TraceDefinition` shows selected events, columns and filters for live server traces. The procedure takes no parameters and returns no defined result set. On error it rolls back any open transaction and rethrows, so avoid nesting it inside unrelated work.

## Parameters and defaults

None.

## Results, permissions, and limits

No parameters or defined result set. Requires view DDL, trace/catalog visibility and extended-property authority. Column set varies with server trace catalog.

## Dependencies

Native dependencies: `sys.fn_listextendedproperty`, `sys.fn_trace_geteventinfo`, `sys.fn_trace_getfilterinfo`, `sys.sp_addextendedproperty`, `sys.sp_dropextendedproperty`, `sys.trace_categories`, `sys.trace_columns`, `sys.trace_event_bindings`, `sys.trace_events`, `sys.traces`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.

These generated views retain their existing native/catalog layouts. TraceID in z.v_TraceDefinition is sys.traces.id; inspect registered destinations and configured filters through z.v_TraceOwned, z.Trace and z.TraceFilter.
