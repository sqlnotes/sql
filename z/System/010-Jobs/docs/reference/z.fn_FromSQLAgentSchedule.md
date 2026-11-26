# z.fn_FromSQLAgentSchedule

[Jobs](../readme.md) | [Source](../../modules/1020%20Functions/z.fn_FromSQLAgentSchedule.sql)

## Purpose and behavior

Converts the numeric fields of an existing SQL Server Agent schedule into readable recurrence, day and time settings. Use it when inspecting schedules from `msdb`; it does not change those schedules.

Pass the ten native timing fields listed below, for example from `msdb.dbo.sysschedules`. The result uses the same normalized columns as [z.fn_CleanseScheduleParameter](z.fn_CleanseScheduleParameter.md), including a readable description.

## Parameters and defaults

```text
@freq_type int,
@freq_interval int,
@freq_subday_type int,
@freq_subday_interval int,
@freq_relative_interval int,
@freq_recurrence_factor int,
@active_start_date int,
@active_end_date int,
@active_start_time int,
@active_end_time int
```

## Results, permissions, and limits

Weekly schedules can contain several weekdays. The conversion preserves all selected days; native weekday bits are Sunday=1, Monday=2, Tuesday=4, Wednesday=8, Thursday=16, Friday=32 and Saturday=64.

No writes or explicit transaction. Requires function access; schedule conversion does not validate a deployed Agent schedule.

## Dependencies

Direct SQL object dependencies: `z.fn_CleanseScheduleParameter`, `z.fn_SQLAgentScheduleTimeToTime`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
