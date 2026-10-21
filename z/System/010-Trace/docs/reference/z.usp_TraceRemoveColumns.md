# z.usp_TraceRemoveColumns

[Trace](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_TraceRemoveColumns.sql)

## Purpose and behavior

Remove selected output-column bindings, preserving SPID (column 12). NULL selects nothing; the whole value all removes removable output columns. Complete catalog names are required. Existing logical filters remain and their inputs are captured separately during collection.

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

z.TraceEventColumn and z.v_TraceColumn; z.v_TraceOwned and z.usp_TraceAssertOwner. See [architecture](../architecture.md) for ownership, execution and transport limits.
