# z.usp_EnableServiceJob

[Jobs](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_EnableServiceJob.sql)

## Purpose and behavior

Resolve the current database-prefixed job by Name and call msdb Agent enable operation when found. Missing job is a no-op. No explicit transaction or catch; native errors propagate.

## Parameters and defaults

```text
@Name nvarchar(255)
```

## Results, permissions, and limits

No defined result set. Requires applicable `msdb` SQL Agent permissions (`msdb.dbo.sp_update_job`).

## Dependencies

Direct SQL object dependencies: `z.fn_GetServiceJobID`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
