# z.fn_CleanseScheduleParameter

[Jobs](../readme.md) | [Source](../../modules/1010%20Functions/z.fn_CleanseScheduleParameter.sql)

## Purpose and behavior

Eight shared schedule inputs -> ScheduleID uniqueidentifier, Frequency, Interval, ByDay, IntradayFrequency, IntradayInterval, ByTime, StartDate, EndDate, Description. Normalize names/tokens, remove duplicates, sort, clamp second intervals to at least 10 and minute/hour intervals to at least 1, default date range 1990-01-01 through 9999-12-31, derive MD5 ScheduleID. Return only rows with a non-null description. Read-only.

## Parameters and defaults

```text
@Frequency varchar(20) = 'Daily', @Interval int = 1, @ByDay varchar(8000) = null,@IntradayFrequency varchar(20) = 'Second', @IntradayInterval int = 10,@ByTime varchar(8000) = '00:00',@StartDate date = null,@EndDate date = null
```

These are the source-declared types and defaults. Table-valued-function callers must supply arguments or the `default` keyword explicitly.

## Results, permissions, and limits

No writes or explicit transaction. Requires function access; schedule conversion does not validate a deployed Agent schedule. See subsystem troubleshooting for known conversion defects.

## Dependencies

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
