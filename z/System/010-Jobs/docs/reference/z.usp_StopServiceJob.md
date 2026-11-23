# z.usp_StopServiceJob

[Jobs](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_StopServiceJob.sql)

## Purpose and behavior

Asks SQL Server Agent to stop a service job belonging to the current database when that job is detected as executing. Pass the service name in `@Name`, without the `z_(DatabaseName)_` prefix. A missing job or one not detected as executing produces no stop request.

The lookup uses the same 128-character job-name limit as creation. Execution detection comes from [z.v_ServiceJobs](supporting-objects.md#zv_servicejobs), so it has that view's session-visibility limits. Native Agent errors are returned to the caller.

## Parameters and defaults

```text
@Name nvarchar(255)
```

## Results, permissions, and limits

No defined result set. Requires applicable msdb Agent permissions.

## Dependencies

Direct SQL object dependencies: `z.fn_GetServiceJobID`, `z.v_ServiceJobs`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
