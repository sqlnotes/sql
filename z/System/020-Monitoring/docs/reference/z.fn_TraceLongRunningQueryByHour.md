# z.fn_TraceLongRunningQueryByHour

[Monitoring](../readme.md) | [Source](../../modules/1030%20Functions/z.fn_TraceLongRunningQueryByHour.sql)

## Purpose and behavior

Read retained z.TraceLongRunningQuery rows whose TraceSequence is at least the generated date cutoff for abs(Days). Group by StartTime date and hour and duration buckets, converting Duration microseconds to milliseconds. Exclude SQLAgent, SSIS, Management Studio, SQLServerCEIP and text containing backup. Null ApplicationName/TextData fail the filters and are excluded.

## Parameters and defaults

```text
@Days int
```

These are the source-declared types and defaults. Table-valued-function callers must supply arguments or the `default` keyword explicitly.

## Results, permissions, and limits

Returns Date (datetime at the start of each hour, retaining the full calendar date) and counts labelled [1.3-5], [5-10], [10-15], [15-20], [20-25], [25-30], [30-60], [60-90], [90-120], [120-180], [180-240], [240+]. Labels use seconds; first bucket counts any duration below 5 seconds, not a separately enforced 1.3-second lower bound. Read-only. Uses the same day-based lookback as z.fn_TraceLongRunningQueryByDay; hours with no matching rows are omitted. StartTime is not converted to another time zone.

## Dependencies

Direct SQL object dependencies: `z.TraceLongRunningQuery`, `z.fn_GenerateZSequenceID`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
