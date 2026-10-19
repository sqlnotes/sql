# z.usp_CreateSchedule

[Jobs](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_CreateSchedule.sql)

## Purpose and behavior

Validate input through z.fn_ValidateScheduleParameter and translate it through z.fn_ToSQLAgentSchedule. Invalid input, an empty conversion result or an overlength database-prefixed name raises error 51000 before schedule writes; a partially invalid list is rejected as a whole. In a transaction, acquire the current database's exclusive transaction-owned job/schedule lock, list schedules with sp_help_schedule, and create missing deterministic names with sp_add_schedule. Existing names are reused only when all timing fields match; enabled state is preserved. Lock acquisition waits at most 15 seconds and failures raise 51001. The lock remains held until the actual outer transaction ends, including when called inside job creation. Commit; on error within the transaction rollback any open transaction and rethrow.

Before creating any missing schedules, compare all ten native timing fields for every existing matching name, accounting for SQL Agent storing a zero end time as 235959. Generated names and creation inputs are preserved. Any mismatch, including a NULL field, raises error 51000 naming the conflicting schedule; no requested schedules are created. Restore the existing schedule's timing or rename it before retrying. Existing enabled/disabled state is preserved, and matching shared schedules are never automatically repaired. ScheduleNames is valid only after successful execution. A thrown error can leave the caller's output variable at its prior value; callers should handle the exception rather than consume that value.

## Parameters and defaults

```text
@Frequency varchar(20) = 'Daily', @Interval int = 1, @ByDay varchar(8000) = null,@IntradayFrequency varchar(20) = 'Second', @IntradayInterval int = 10,@ByTime varchar(8000) = '00:00',@StartDate date = null,@EndDate date = null,@ScheduleNames nvarchar(max) = null output
```

These are the source-declared types and defaults.

## Results, permissions, and limits

ScheduleNames is a Unicode comma-joined display string, reset to null at entry. Database names can contain commas, so do not split this string to recover names; select Name rows from z.fn_ToSQLAgentSchedule instead. No defined result set. Requires msdb schedule authority; schedules reside in msdb and use the current database's prefix.

## Dependencies

Direct SQL object dependencies: `z.fn_ValidateScheduleParameter`, `z.fn_ResourceSQLScheduleOperation`, `z.fn_ToSQLAgentSchedule`.

Native dependencies: `sys.sp_getapplock`, `msdb.dbo.sp_add_schedule`, `msdb.dbo.sp_help_schedule`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
