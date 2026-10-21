# z.usp_TraceRemoveEvents

[Trace](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_TraceRemoveEvents.sql)

## Purpose and behavior

Remove selected logical events, their output-column bindings and event-specific callback registrations. NULL selects nothing; the whole value all removes all selected events. Complete catalog names are required. Other logical definitions are unaffected.

## Parameters and defaults

```text
@TraceName nvarchar(128) = null,
@TraceID int = null,
@EventList nvarchar(max) = null
```

TraceName/TraceID select one current-session logical definition. When both are supplied they must identify the same owned definition. TraceID is not a native SQL Trace ID.

## Ownership, results and limits

Requires the registered UUID/session/login owner and a Building run; Collecting configuration is frozen. Logical Start does not end Building, so these APIs can still run after enabling a definition. No defined result set. Requires configuration metadata access and catalog visibility; collection separately requires native trace and destination/callback privileges. Use framework procedures instead of direct table DML.

## Dependencies

z.TraceEvent, z.TraceEventColumn, z.TraceTrigger and z.v_TraceEvent; z.v_TraceOwned and z.usp_TraceAssertOwner. See [architecture](../architecture.md) for ownership, execution and transport limits.
