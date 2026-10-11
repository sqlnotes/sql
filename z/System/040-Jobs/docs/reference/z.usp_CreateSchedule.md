# z.usp_CreateSchedule

[Jobs](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_CreateSchedule.sql)

## Purpose and behavior

Normalize/translate input through z.fn_ToSQLAgentSchedule. If no rows, return without changes. In a transaction, acquire the shared System semaphore, list schedules with sp_help_schedule, and create missing deterministic names with sp_add_schedule. Existing names are reused without property reconciliation. Release semaphore and commit; on error rollback any open transaction and rethrow.

## Parameters and defaults

```text
@Frequency varchar(20) = 'Daily', @Interval int = 1, @ByDay varchar(8000) = null,@IntradayFrequency varchar(20) = 'Second', @IntradayInterval int = 10,@ByTime varchar(8000) = '00:00',@StartDate date = null,@EndDate date = null,@ScheduleNames varchar(max) = null output
```

These are the source-declared types and defaults.

## Results, permissions, and limits

ScheduleNames is a comma-separated output string, reset to null at entry. No defined result set. Requires msdb schedule authority; creation is server-wide.

## Dependencies

Direct SQL object dependencies: `z.fn_ResourceSQLScheduleOperation`, `z.fn_ToSQLAgentSchedule`, `z.usp_AcquireSemaphore`, `z.usp_ReleaseSemaphore`.

Native dependencies: `msdb.dbo.sp_add_schedule`, `msdb.dbo.sp_help_schedule`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
