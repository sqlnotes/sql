# z.usp_TraceAddColumns

[Trace](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_TraceAddColumns.sql)

## Purpose and behavior

Add supported output columns to the selected logical definition's events. NULL selects no columns; the whole value all selects catalog columns. Lists use complete catalog names and reject unknown/empty entries. No native trace is allocated. Filter inputs are collected separately even if absent from output selection.

## Parameters and defaults

```text
@TraceName nvarchar(128) = null,
@TraceID int = null,
@EventColumnList nvarchar(max) = null
```

TraceName/TraceID select one current-session logical definition. When both are supplied they must identify the same owned definition. TraceID is not a native SQL Trace ID.

## Ownership, results and limits

Requires the registered UUID/session/login owner and a Building run; Collecting configuration is frozen. Logical Start does not end Building, so these APIs can still run after enabling a definition. No defined result set. Requires configuration metadata access and catalog visibility; collection separately requires native trace and destination/callback privileges. Use framework procedures instead of direct table DML.

## Dependencies

z.TraceEvent, z.TraceEventColumn and z.v_TraceColumn; z.v_TraceOwned and z.usp_TraceAssertOwner. See [architecture](../architecture.md) for ownership, execution and transport limits.
