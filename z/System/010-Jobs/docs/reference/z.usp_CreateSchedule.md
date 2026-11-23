# z.usp_CreateSchedule

[Jobs](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_CreateSchedule.sql)

## Purpose and behavior

Creates the SQL Server Agent schedules needed for a readable schedule definition, or reuses equivalent schedules already owned by the current database. Use it when you need schedule IDs to attach to jobs; [z.usp_CreateServiceJob](z.usp_CreateServiceJob.md) normally does this for you.

Describe the recurrence using [the shared schedule parameters](../usage.md#schedule-vocabulary). Invalid input, a partly invalid list, or an overlength database-prefixed name raises error 51000 before any requested schedules are created. Existing schedules keep their enabled or disabled state.

Reused schedules must still match the timing encoded in their names. If a schedule has been manually changed without being renamed, error 51000 identifies the conflict before any requested schedules are created. Restore its timing or rename it before retrying; another job may share it. The procedure does not repair or enable existing schedules automatically.

An omitted `@StartDate` uses SQL Server's local date; an omitted `@EndDate` is unlimited (`9999-12-31`). Specific schedules take execution dates from `@ByDay` and ignore these two date parameters. A date-only Specific value runs at midnight.

Schedules can be shared only within the current database and with matching timing and end date. For daily interval-one schedules, an equivalent schedule that has already started can be reused despite a different historical start date. Future starts and other frequencies require the same start date. An exact date match is preferred; otherwise the lowest eligible schedule ID is used.

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

Use `@ScheduleIDs output` to receive the schedules that were created or reused, and `@ScheduleNames output` for their display names. Callers normally omit `@OperationDate`; it lets nested job/schedule creation use the same local date for default start dates and historical schedule reuse.

## Results, permissions, and limits

Schedule changes are serialized within the current database. A competing change waits up to 15 seconds; lock acquisition failure raises error 51001. Protection lasts until the outer transaction ends. A transactional error rolls back any open transaction, including a caller's transaction, then rethrows the error.

`@ScheduleIDs` is a JSON array of distinct integer IDs, for example `[12,34]`, ordered by ID. `@ScheduleNames` contains their display names in the same order. Names can contain commas, so use the IDs rather than splitting the display string. The actual names can differ from a conversion preview when a historical schedule is reused.

There is no defined result set. Consume outputs only after successful execution; an exception can leave a receiving variable's previous value unchanged. The caller needs schedule-management permissions in `msdb`.

## Dependencies

Direct SQL object dependencies: `z.fn_GetScheduleNamePrefix`, `z.fn_ValidateScheduleParameter`, `z.fn_ResourceSQLScheduleOperation`, `z.fn_ToSQLAgentSchedule`.

Shared dependency: `z.usp_AcquireSemaphore`. Native dependencies: `msdb.dbo.sp_add_schedule`, `msdb.dbo.sp_help_schedule`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
