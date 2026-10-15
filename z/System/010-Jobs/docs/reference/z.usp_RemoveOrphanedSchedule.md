# z.usp_RemoveOrphanedSchedule

[Jobs](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_RemoveOrphanedSchedule.sql)

## Purpose and behavior

In a transaction and shared semaphore, list schedules via sp_help_schedule and delete job_count=0 rows. Default restricts names to Schema z:%; AllOrphanedSchedules=1 includes every visible orphaned schedule. Release semaphore/commit; catch rolls back any open transaction and rethrows.

## Parameters and defaults

```text
@AllOrphanedSchedules bit = 0
```

These are the source-declared types and defaults.

## Results, permissions, and limits

No defined result set. Requires msdb schedule-deletion authority. Scope can extend beyond this database and beyond this product.

## Dependencies

Direct SQL object dependencies: `z.fn_ResourceSQLScheduleOperation`, `z.usp_AcquireSemaphore`, `z.usp_ReleaseSemaphore`.

Native dependencies: `msdb.dbo.sp_delete_schedule`, `msdb.dbo.sp_help_schedule`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
