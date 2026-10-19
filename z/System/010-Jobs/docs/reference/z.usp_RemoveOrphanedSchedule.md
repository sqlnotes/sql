# z.usp_RemoveOrphanedSchedule

[Jobs](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_RemoveOrphanedSchedule.sql)

## Purpose and behavior

In a transaction protected by the current database's exclusive job/schedule application lock, list schedules via sp_help_schedule and delete job_count=0 rows whose names match z.fn_GetScheduleNamePrefix literally. Wildcards in database names have no special meaning. Legacy global names and other databases' schedules are excluded. AllOrphanedSchedules=1 raises error 51000 before work; global cleanup cannot be coordinated by a database-local lock. Lock acquisition waits at most 15 seconds; failure raises 51001. Commit releases protection only when the actual outer transaction ends; catch rolls back any open transaction and rethrows.

## Parameters and defaults

```text
@AllOrphanedSchedules bit = 0
```

These are the source-declared types and defaults.

## Results, permissions, and limits

No defined result set. Requires msdb schedule-deletion authority. Cleanup is limited to the current database prefix. The legacy parameter remains for signature compatibility; NULL and 0 use scoped cleanup, and 1 is rejected.

## Dependencies

Direct SQL object dependencies: `z.fn_ResourceSQLScheduleOperation`, `z.fn_GetScheduleNamePrefix`.

Native dependencies: `sys.sp_getapplock`, `msdb.dbo.sp_delete_schedule`, `msdb.dbo.sp_help_schedule`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
