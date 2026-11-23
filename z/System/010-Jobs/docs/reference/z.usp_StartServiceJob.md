# z.usp_StartServiceJob

[Jobs](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_StartServiceJob.sql)

## Purpose and behavior

Asks SQL Server Agent to start a service job belonging to the current database. Pass the service name in `@Name`, without the `z_(DatabaseName)_` prefix. If the job does not exist, the call finishes without doing anything.

A successful call means the start request was accepted, not that the job has started or completed. Use [z.usp_GetJobStatus](z.usp_GetJobStatus.md) to inspect its state and outcome. Native Agent errors are returned to the caller.

## Parameters and defaults

```text
@Name nvarchar(255)
```

## Results, permissions, and limits

No defined result set. Requires applicable msdb Agent permissions; starting is asynchronous and does not return job completion status.

## Dependencies

Direct SQL object dependencies: `z.fn_GetServiceJobID`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
