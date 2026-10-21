# z.fn_TraceLongRunningQueryByDay

[Monitoring](../readme.md) | [Source](../../modules/1030%20Functions/z.fn_TraceLongRunningQueryByDay.sql)

## Purpose and behavior

Read retained z.TraceLongRunningQuery rows whose TraceSequence is at least the generated date cutoff for abs(Days). Group by StartTime date and duration buckets, converting Duration microseconds to milliseconds. Exclude SQLAgent, SSIS, Management Studio, SQLServerCEIP and text containing backup. Null ApplicationName/TextData fail the filters and are excluded.

## Parameters and defaults

```text
@Days int
```

These are the source-declared types and defaults. Table-valued-function callers must supply arguments or the `default` keyword explicitly.

## Results, permissions, and limits

Returns Date and counts labelled [1.3-5], [5-10], [10-15], [15-20], [20-25], [25-30], [30-60], [60-90], [90-120], [120-180], [180-240], [240+]. Labels use seconds; first bucket counts any duration below 5 seconds, not a separately enforced 1.3-second lower bound. Read-only.

## Dependencies

Direct SQL object dependencies: `z.TraceLongRunningQuery`, `z.fn_GenerateZSequenceID`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
