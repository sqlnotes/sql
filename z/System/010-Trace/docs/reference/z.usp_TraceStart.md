# z.usp_TraceStart

[Trace](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_TraceStart.sql)

## Purpose and behavior

Enable matching logical definitions in the current Building run by setting IsEnabled=1. With neither selector supplied, enable all current-run definitions. Allocate no native trace and start no reader. Events, columns, filters and callbacks may still be configured while Building. Collect creates the overlapping physical generations later. Stop and Close may select logical definitions across owners; Start still requires its owning session.

## Parameters and defaults

```text
@TraceName nvarchar(128) = null,
@TraceID int = null
```

## Results, permissions and limits

No defined result set. Requires registered owner and metadata access. Collecting runs are frozen.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for run ownership, schema compatibility and known transport limits.
