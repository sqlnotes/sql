# z.usp_DisableServiceJob

[Jobs](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_DisableServiceJob.sql)

## Purpose and behavior

Disables a service job belonging to the current database so Agent will not start it on its schedule. Pass the service name in `@Name`, without the `z_(DatabaseName)_` prefix. If the job does not exist, the call finishes without doing anything.

This changes the job's enabled setting; use [z.usp_StopServiceJob](z.usp_StopServiceJob.md) to request that a currently executing job stop. Native Agent errors are returned to the caller.

## Parameters and defaults

```text
@Name nvarchar(255)
```

## Results, permissions, and limits

No defined result set. Requires applicable `msdb` SQL Agent permissions (`msdb.dbo.sp_update_job`).

## Dependencies

Direct SQL object dependencies: `z.fn_GetServiceJobID`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
