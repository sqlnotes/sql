# z.usp_TraceStop

[Trace](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_TraceStop.sql)

Stop selected registered native traces without deleting their configuration. Explicit name/ID selectors may target another creator when SQL permissions allow; no selector means the current session/login. Already-stopped or vanished matching traces are normal. Actions use the registered TraceID under its registration lock. The trace can be explicitly started again with the same native configuration. Change events/columns/filters by closing and recreating it.

```text
@TraceName nvarchar(128) = null,
@TraceID int = null
```

TraceID is the native SQL Server trace ID. Configuration and Start require the creator session/login; explicit Stop/Close selectors can target another creator when permissions allow. Native SQL Trace permissions are not granted by these procedures. See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md).
