# z.usp_TraceAddEvents

[Trace](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_TraceAddEvents.sql)

## Purpose and behavior

Add explicit events and supported output-column bindings to one owned logical definition. NULL EventList does nothing; NULL EventColumnList inherits existing output columns. SPID is included where supported. Lists use complete catalog names, trim whitespace, deduplicate values and reject unknown/empty entries before writes. The whole value all is supported for columns, not event names. Configuration changes metadata only; it does not allocate or configure a native trace.

## Parameters and defaults

```text
@TraceName nvarchar(128) = null,
@TraceID int = null,
@EventList nvarchar(max) = null,
@EventColumnList nvarchar(max) = null
```

TraceName/TraceID select one current-session logical definition. When both are supplied they must identify the same owned definition. TraceID is not a native SQL Trace ID.

## Ownership, results and limits

Requires the registered UUID/session/login owner and a Building run; Collecting configuration is frozen. Logical Start does not end Building, so these APIs can still run after enabling a definition. No defined result set. Requires configuration metadata access and catalog visibility; collection separately requires native trace and destination/callback privileges. Use framework procedures instead of direct table DML.

## Dependencies

z.TraceEvent, z.TraceEventColumn, z.v_TraceEvent, z.v_TraceColumn and sys.trace_event_bindings; z.v_TraceOwned and z.usp_TraceAssertOwner. See [architecture](../architecture.md) for ownership, execution and transport limits.
