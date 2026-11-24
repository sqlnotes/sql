# z.fn_TraceLongRunningQueryByDay

[Monitoring](../readme.md) | [Source](../../modules/1030%20Functions/z.fn_TraceLongRunningQueryByDay.sql)

## Purpose and behavior

Summarizes retained long-running-query Trace data by day and execution-duration range. Use it to see whether slow-query counts are increasing without starting a new collection. It reads `z.TraceLongRunningQuery`; the Trace collector must already have saved the events.

`@Days` selects a day-based lookback using its absolute value. Results group events by their recorded StartTime date. SQLAgent, SSIS, Management Studio, SQLServerCEIP and SQL text containing `backup` are excluded, as are rows with missing application name or SQL text.

## Parameters and defaults

```text
@Days int
```

## Results, permissions, and limits

Returns Date and counts labelled [1.3-5], [5-10], [10-15], [15-20], [20-25], [25-30], [30-60], [60-90], [90-120], [120-180], [180-240], [240+]. Labels use seconds; first bucket counts any duration below 5 seconds, not a separately enforced 1.3-second lower bound. Read-only.

## Dependencies

Direct SQL object dependencies: `z.TraceLongRunningQuery`, `z.fn_GenerateZSequenceID`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
