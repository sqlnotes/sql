# z.fn_FromSQLAgentSchedule

[Jobs](../readme.md) | [Source](../../modules/1020%20Functions/z.fn_FromSQLAgentSchedule.sql)

## Purpose and behavior

Ten required int inputs in native order: freq_type, freq_interval, freq_subday_type, freq_subday_interval, freq_relative_interval, freq_recurrence_factor, active_start_date, active_end_date, active_start_time, active_end_time. Return normalized schedule columns through z.fn_CleanseScheduleParameter. Read-only. Weekly bit64 mapping is incorrect.

## Parameters and defaults

```text
@freq_type int,@freq_interval int,@freq_subday_type int,@freq_subday_interval int,@freq_relative_interval int,@freq_recurrence_factor int,@active_start_date int,@active_end_date int,@active_start_time int,@active_end_time int
```

These are the source-declared types and defaults. Table-valued-function callers must supply arguments or the `default` keyword explicitly.

## Results, permissions, and limits

No writes or explicit transaction. Requires function access; schedule conversion does not validate a deployed Agent schedule. See subsystem troubleshooting for known conversion defects.

## Dependencies

Direct SQL object dependencies: `z.fn_CleanseScheduleParameter`, `z.fn_SQLAgentScheduleTimeToTime`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
