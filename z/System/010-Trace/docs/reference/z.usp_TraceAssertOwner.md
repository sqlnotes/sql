# z.usp_TraceAssertOwner

[Trace](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_TraceAssertOwner.sql)

Require a matching registration created by the current session ID/login time. No UUID or separate collector registration is used. This helper validates metadata selection; native operations use the registered TraceID.

```text
@TraceName nvarchar(128) = null,
@TraceID int = null
```

TraceID is the native SQL Server trace ID. Configuration and Start require the creator session/login; explicit Stop/Close selectors can target another creator when permissions allow. Native SQL Trace permissions are not granted by these procedures. See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md).
