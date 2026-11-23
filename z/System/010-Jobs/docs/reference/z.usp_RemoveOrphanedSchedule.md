# z.usp_RemoveOrphanedSchedule

[Jobs](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_RemoveOrphanedSchedule.sql)

## Purpose and behavior

Deletes schedules owned by the current database that are no longer attached to any SQL Agent job. Use it after removing jobs or changing their schedules to clean up unused definitions in `msdb`.

Schedules belonging to other databases and legacy global schedules are retained. The database prefix is matched literally, so punctuation or wildcard characters in a database name do not widen the cleanup scope. `@AllOrphanedSchedules` is retained for compatibility: omit it or pass 0 (NULL also uses scoped cleanup); passing 1 raises error 51000.

## Parameters and defaults

```text
@AllOrphanedSchedules bit = 0
```

## Results, permissions, and limits

Job and schedule changes are serialized within the database. Lock acquisition waits up to 15 seconds; failure raises 51001. Protection lasts until the outer transaction ends. An error rolls back any open transaction, including a caller's transaction, and is rethrown.

No defined result set. Requires msdb schedule-deletion authority. Cleanup is limited to the current database prefix. The legacy parameter remains for signature compatibility; NULL and 0 use scoped cleanup, and 1 is rejected.

## Dependencies

Direct SQL object dependencies: `z.fn_ResourceSQLScheduleOperation`, `z.fn_GetScheduleNamePrefix`.

Shared dependency: `z.usp_AcquireSemaphore`. Native dependencies: `msdb.dbo.sp_delete_schedule`, `msdb.dbo.sp_help_schedule`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
