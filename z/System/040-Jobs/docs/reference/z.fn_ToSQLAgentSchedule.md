# z.fn_ToSQLAgentSchedule

[Jobs](../readme.md) | [Source](../../modules/1020%20Functions/z.fn_ToSQLAgentSchedule.sql)

## Purpose and behavior

Eight shared schedule inputs -> Name varchar(128) and ten native integer schedule fields. Split requested days/times into combinations, consolidate weekly bitmasks, and derive deterministic Schema z: names. Read-only; inspect returned fields before use.

## Parameters and defaults

```text
@Frequency varchar(20) = 'Daily', @Interval int = 1, @ByDay varchar(8000) = null,@IntradayFrequency varchar(20) = 'Second', @IntradayInterval int = 10,@ByTime varchar(8000) = '00:00',@StartDate date = null,@EndDate date = null
```

These are the source-declared types and defaults. Table-valued-function callers must supply arguments or the `default` keyword explicitly.

## Results, permissions, and limits

No writes or explicit transaction. Requires function access; schedule conversion does not validate a deployed Agent schedule. See subsystem troubleshooting for known conversion defects.

## Dependencies

Direct SQL object dependencies: `z.ByDay`, `z.ByTime`, `z.Frequency`, `z.Interval`, `z.ScheduleID`, `z.fn_CleanseScheduleParameter`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
