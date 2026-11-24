# z.usp_TraceAssertOwner

[Trace](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_TraceAssertOwner.sql)

Checks that the selected trace belongs to the current connection. Configuration and Start use this helper to keep one connection from changing another connection's trace. It validates the registration without starting, stopping or collecting a trace.

Select by `@TraceName` or `@TraceID`; when both are supplied they must identify the same registration. Ownership includes the connection's login time, so a reused session ID does not inherit a previous connection's traces.

```text
@TraceName nvarchar(128) = null,
@TraceID int = null
```

TraceID is the native SQL Server trace ID. Configuration and Start require the creator session/login; explicit Stop/Close selectors can target another creator when permissions allow. Native SQL Trace permissions are not granted by these procedures. See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md).
