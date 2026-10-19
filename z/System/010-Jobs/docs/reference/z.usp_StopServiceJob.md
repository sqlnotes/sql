# z.usp_StopServiceJob

[Jobs](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_StopServiceJob.sql)

## Purpose and behavior

Resolve the current database-prefixed job ID through z.fn_GetServiceJobID, using the same truncated nvarchar(128) identity as creation, and call the msdb Agent stop operation when found. Stop only when z.v_ServiceJobs identifies a matching executing service. No explicit transaction or catch; native errors propagate.

## Parameters and defaults

```text
@Name nvarchar(255)
```

These are the source-declared types and defaults.

## Results, permissions, and limits

No defined result set. Requires applicable msdb Agent permissions.

## Dependencies

Direct SQL object dependencies: `z.fn_GetServiceJobID`, `z.v_ServiceJobs`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
