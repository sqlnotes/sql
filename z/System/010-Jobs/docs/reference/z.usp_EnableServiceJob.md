# z.usp_EnableServiceJob

[Jobs](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_EnableServiceJob.sql)

## Purpose and behavior

Enables a service job belonging to the current database so Agent can run it on its schedule. Pass the service name in `@Name`, without the `z_(DatabaseName)_` prefix. If the job does not exist, the call finishes without doing anything.

Enabling does not start the job immediately; use [z.usp_StartServiceJob](z.usp_StartServiceJob.md) for that. Native Agent errors are returned to the caller.

## Parameters and defaults

```text
@Name nvarchar(255)
```

## Results, permissions, and limits

No defined result set. Requires applicable `msdb` SQL Agent permissions (`msdb.dbo.sp_update_job`).

## Dependencies

Direct SQL object dependencies: `z.fn_GetServiceJobID`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
