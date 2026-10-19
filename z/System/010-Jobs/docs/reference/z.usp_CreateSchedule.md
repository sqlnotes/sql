# z.usp_CreateSchedule

[Jobs](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_CreateSchedule.sql)

## Purpose and behavior

Validate input through z.fn_ValidateScheduleParameter and translate it through z.fn_ToSQLAgentSchedule. Invalid input, an empty conversion result or an overlength database-prefixed name raises error 51000 before schedule writes; a partially invalid list is rejected as a whole. In a transaction, acquire the current database's exclusive transaction-owned job/schedule lock, list schedules with sp_help_schedule, and create missing deterministic names with sp_add_schedule. Resolve eligible schedules by native timing fields; enabled state is preserved. Lock acquisition waits at most 15 seconds and failures raise 51001. The lock remains held until the actual outer transaction ends, including when called inside job creation. Commit; on error within the transaction rollback any open transaction and rethrow.

Before creating any missing schedules, compare all ten native timing fields against each same-name schedule and eligible reuse candidate's own encoded tuple, accounting for SQL Agent storing a zero end time as 235959. Candidates qualify by their encoded or actual timing, so relevant shared schedules with drift are rejected. Generated names and creation inputs are preserved. Any mismatch, including a NULL field, raises error 51000 naming the conflicting schedule; no requested schedules are created. Restore the existing schedule's timing or rename it before retrying. Existing enabled/disabled state is preserved, and matching shared schedules are never automatically repaired. ScheduleNames and ScheduleIDs are valid only after successful execution. A thrown error can leave the caller's output variable at its prior value; callers should handle the exception rather than consume that value.

An omitted StartDate uses the SQL Server local date; EndDate remains unlimited (9999-12-31). Creation captures one operation date and passes it through validation, conversion and nested schedule creation. Explicit dates and recurring ByTime defaults are unchanged. Specific derives execution dates from ByDay, ignores StartDate/EndDate, and retains date-only values as midnight.

Reuse requires the current database's literal prefix and matching native timing fields/end date. For every-day schedules (daily interval one), different start dates can share a schedule when both are on or before the captured operation date. Future starts require the same start date. Multi-day, weekly, monthly and other frequencies retain exact start-date matching. Prefer an exact date match, then the lowest schedule ID among eligible historical starts. Disabled schedules stay disabled. No existing schedule is renamed or modified.

## Parameters and defaults

```text
@Frequency varchar(20) = 'Daily',
@Interval int = 1,
@ByDay varchar(8000) = null,
@IntradayFrequency varchar(20) = 'Second',
@IntradayInterval int = 10,
@ByTime varchar(8000) = '00:00',
@StartDate date = null,
@EndDate date = null,
@ScheduleNames nvarchar(max) = null output,
@ScheduleIDs nvarchar(max) = null output,
@OperationDate date = null
```

These are the source-declared types and defaults. OperationDate coordinates nested creation: callers normally omit it, using the captured SQL Server local date. CreateServiceJob supplies its captured operation date. When explicitly supplied, it controls omitted StartDate and the historical-start reuse boundary.

## Results, permissions, and limits

ScheduleNames is a Unicode comma-joined display string of actual resolved names. ScheduleIDs is a JSON array of distinct integer IDs (for example [12,34]), ordered by ID, with names in the same order. Both outputs are reset to null internally at entry. Database names can contain commas, so do not split ScheduleNames. Consume ScheduleIDs through OPENJSON and use native schedule-ID parameters. Converter Name rows describe requested names and may differ from reused historical names. No defined result set. Requires msdb schedule authority; schedules reside in msdb and use the current database's prefix.

## Dependencies

Direct SQL object dependencies: `z.fn_GetScheduleNamePrefix`, `z.fn_ValidateScheduleParameter`, `z.fn_ResourceSQLScheduleOperation`, `z.fn_ToSQLAgentSchedule`.

Native dependencies: `sys.sp_getapplock`, `msdb.dbo.sp_add_schedule`, `msdb.dbo.sp_help_schedule`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
