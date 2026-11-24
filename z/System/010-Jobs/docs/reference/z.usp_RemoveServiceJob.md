# z.usp_RemoveServiceJob

[Jobs](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_RemoveServiceJob.sql)

## Purpose and behavior

Deletes a service job belonging to the current database while retaining its schedules. Pass the service name in `@Name`, without the `z_(DatabaseName)_` prefix. Removing a job that is already absent succeeds without doing anything.

Use [z.usp_RemoveOrphanedSchedule](z.usp_RemoveOrphanedSchedule.md) afterward if you also want to remove this database's schedules that no jobs use. Shared and legacy schedules are not deleted as part of job removal.

## Parameters and defaults

```text
@Name nvarchar(255)
```

## Results, permissions, and limits

Job and schedule changes are serialized within the database. Lock acquisition waits up to 15 seconds; failure raises 51001. Protection lasts until the outer transaction ends. An error rolls back any open transaction, including a caller's transaction, and is rethrown.

No defined result set. Requires applicable msdb Agent permissions. Schedule rows are retained; use z.usp_RemoveOrphanedSchedule for database-scoped cleanup.

## Dependencies

Direct SQL object dependencies: `z.fn_GetServiceJobID`, `z.fn_ResourceSQLScheduleOperation`. Shared dependency: `z.usp_AcquireSemaphore`. Native dependencies: `msdb.dbo.sp_delete_job`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
