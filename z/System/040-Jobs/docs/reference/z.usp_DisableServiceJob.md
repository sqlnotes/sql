# z.usp_DisableServiceJob

[Jobs](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_DisableServiceJob.sql)

## Purpose and behavior

Resolve the current database-prefixed job by Name and call msdb Agent disable operation when found. Missing job is a no-op. No explicit transaction or catch; native errors propagate.

## Parameters and defaults

```text
@Name nvarchar(255)
```

These are the source-declared types and defaults.

## Results, permissions, and limits

No defined result set. Requires applicable msdb Agent permissions; starting is asynchronous and does not return job completion status.

## Dependencies

Direct SQL object dependencies: `z.fn_GetServiceJobID`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
