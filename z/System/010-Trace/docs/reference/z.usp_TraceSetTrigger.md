# z.usp_TraceSetTrigger

[Trace](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_TraceSetTrigger.sql)

## Purpose and behavior

Create or replace the callback registration for all events or one selected event. ProcedureName must resolve to an existing stored procedure in the current database; store its quoted schema-qualified name. EventName all overrides an event-specific registration. Callbacks receive three named parameters: @TraceSequence bigint, @TraceID int (logical) and @EventName nvarchar(128). Callback execution follows the destination insert and shares its transaction.

## Parameters and defaults

```text
@TraceName nvarchar(128) = null,
@TraceID int = null,
@EventName nvarchar(128) = N'all',
@ProcedureName nvarchar(517)
```

TraceName/TraceID select one current-session logical definition. When both are supplied they must identify the same owned definition. TraceID is not a native SQL Trace ID.

## Ownership, results and limits

Requires the registered UUID/session/login owner and a Building run; Collecting configuration is frozen. Logical Start does not end Building, so these APIs can still run after enabling a definition. No defined result set. Requires configuration metadata access and catalog visibility; collection separately requires native trace and destination/callback privileges. Use framework procedures instead of direct table DML.

## Dependencies

z.TraceTrigger, z.TraceEvent and z.v_TraceEvent; z.v_TraceOwned and z.usp_TraceAssertOwner. See [architecture](../architecture.md) for ownership, execution and transport limits.
