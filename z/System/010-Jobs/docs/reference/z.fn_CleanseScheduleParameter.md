# z.fn_CleanseScheduleParameter

[Jobs](../readme.md) | [Source](../../modules/1010%20Functions/z.fn_CleanseScheduleParameter.sql)

## Purpose and behavior

Turns a readable schedule into a consistent representation that the other Jobs helpers can compare and convert. It standardizes equivalent names and removes repeated days or times without creating or changing an Agent schedule.

The returned row contains `ScheduleID`, the eight normalized schedule fields, and a readable `Description`. Only rows with a description are returned. Use [the shared schedule parameters](../usage.md#schedule-vocabulary) to choose the days, times and recurrence you want.

## Parameters and defaults

```text
@Frequency varchar(20) = 'Daily',
@Interval int = 1,
@ByDay varchar(8000) = null,
@IntradayFrequency varchar(20) = 'Second',
@IntradayInterval int = 10,
@ByTime varchar(8000) = '00:00',
@StartDate date = null,
@EndDate date = null
```

## Results, permissions, and limits

An omitted recurring start date becomes SQL Server's local date, and an omitted end date becomes `9999-12-31`. Repeating seconds are at least 10; repeating minutes and hours are at least 1. Equivalent normalized definitions receive the same MD5-derived `ScheduleID`.

No writes or explicit transaction. Requires function access; schedule conversion does not validate a deployed Agent schedule.

This is the normalization helper, not the validation boundary. Direct calls can discard unrecognized tokens. Use z.fn_ValidateScheduleParameter for complete-input validation or z.fn_ToSQLAgentSchedule for validated native conversion. Agent Start produces the normalized frequency Agent Starts.

Frequency, intraday and weekday/monthly vocabulary is interpreted using explicit Latin1_General_100_CI_AS comparisons. Letter case therefore does not change accepted schedule meaning, including in case-sensitive or Turkish databases. Accents remain significant. Canonical output spellings and ScheduleID generation are preserved. This does not change database collation, database names or user command text.

## Dependencies

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
