# z.usp_TraceStop

[Trace](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_TraceStop.sql)

## Purpose and behavior

Disable matching logical definitions in the current Building run by setting IsEnabled=0. With neither selector supplied, disable all current-run definitions. This changes logical configuration only and does not issue native stop commands. Stop is rejected once Collect freezes the run.

## Parameters and defaults

```text
@TraceName nvarchar(128) = null,
@TraceID int = null
```

## Results, permissions and limits

No defined result set. Requires registered owner and metadata access. End/cancel collection and rebuild a run to change Collecting configuration.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for run ownership, schema compatibility and known transport limits.
