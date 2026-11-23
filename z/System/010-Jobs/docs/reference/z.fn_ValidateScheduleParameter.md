# z.fn_ValidateScheduleParameter

[Jobs](../readme.md) | [Source](../../modules/1010%20Functions/z.fn_ValidateScheduleParameter.sql)

## Purpose and behavior

Checks whether a readable schedule definition is valid before you create a job or schedule. It makes no changes. A NULL result means the input is valid; otherwise the `nvarchar(4000)` result explains which parameter needs attention.

Use [the shared schedule parameters](../usage.md#schedule-vocabulary) to describe the recurrence, days and times. The creation procedures use the same validation and raise its message as error 51000. [z.fn_ToSQLAgentSchedule](z.fn_ToSQLAgentSchedule.md) previews valid input as native Agent fields and returns no rows for invalid input.

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

Function callers must supply all arguments or use the `default` keyword explicitly.

## Validation contract

Accept supported frequency and intraday aliases; validate every relevant day/date/time token and reject empty list members. An omitted StartDate uses the SQL Server local date; EndDate defaults to 9999-12-31. Effective dates must be on or after 1990-01-01 and in ascending order when used by the selected mode. Specific derives its actual execution dates from ByDay and ignores supplied StartDate and EndDate; each actual date must be on or after 1990-01-01. Parameters unused by the selected frequency retain their ignored behavior. Recurrence defaults/minimums and intraday interval minimums retain their normalization behavior. A lone repeating start time retains its existing full-day expansion; explicit reversed time ranges are rejected.

Frequency aliases include D/DD/Day/Days, W/WK/Week/Weeks, M/MM/Mon/Month/Months, Once/One/OneTime/One-Time/Custom/Adhoc, S/Start/Starts/SQLAgentStart and I. Spaces and case are normalized by validation; arbitrary substring matches are rejected. Intraday aliases include H/HH/Hour/Hours, M/MM/Min/Minutes, Sec/Seconds and the Specific aliases above. Weekly days accept standard full names, Mon/Tue/Tues/Wed/Thur/Thurs/Fri/Sat/Sun or numbers 1 (Monday) through 7 (Sunday). Monthly relative days combine First/1st, Second/2nd, Third/3rd, Fourth/4th or Last with a weekday, Day, Weekday or Weekend. Numeric monthly days are canonicalized before deduplication, so 1 and 01 represent the same day.

Schedule vocabulary uses explicit Latin1_General_100_CI_AS semantics, shared with normalization and native day conversion. Case folding is performed under that collation before matching, so uppercase IDLE and mixed-case weekday/monthly aliases retain their meaning under Turkish and case-sensitive database collations. Accents remain significant. Database collation and identifier/command comparisons are not changed.

A valid result describes accepted input, not proof that SQL Agent has accepted or executed a schedule. This function does not check Agent permissions, current service status, job identity or shared schedule drift.

Combined database-prefixed name length is checked by z.fn_ToSQLAgentSchedule. Validation can return NULL while conversion returns no rows because at least one complete name exceeds 128 UTF-16 code units.

## Dependencies

Built-in conversion and string functions only. No writes or explicit transaction.
