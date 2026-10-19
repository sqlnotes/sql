# z.usp_RemoveServiceJob

[Jobs](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_RemoveServiceJob.sql)

## Purpose and behavior

Acquire the current database's exclusive transaction-owned job/schedule application lock, then resolve the current database-prefixed job by Name and remove it when found. Missing job is a no-op. Pass delete_unused_schedule=0 so job removal cannot delete legacy or shared schedules; current-database orphan cleanup is a separate operation. The lock waits at most 15 seconds; failure raises 51001. Commit retains protection until the actual outer transaction ends; errors roll back any open transaction and rethrow.

## Parameters and defaults

```text
@Name nvarchar(255)
```

These are the source-declared types and defaults.

## Results, permissions, and limits

No defined result set. Requires applicable msdb Agent permissions. Schedule rows are retained; use z.usp_RemoveOrphanedSchedule for database-scoped cleanup.

## Dependencies

Direct SQL object dependencies: `z.fn_GetServiceJobID`, `z.fn_ResourceSQLScheduleOperation`. Native dependencies: `sys.sp_getapplock`, `msdb.dbo.sp_delete_job`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
