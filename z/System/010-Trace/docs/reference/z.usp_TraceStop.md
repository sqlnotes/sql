# z.usp_TraceStop

[Trace](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_TraceStop.sql)

Pauses capture while keeping the trace and its configuration available for a later Start. Collected data is retained. Stopping a trace that is already stopped or no longer available is a normal outcome.

Use `@TraceName` or `@TraceID` to select a trace, including another connection's trace when permissions allow. Omit both to stop this connection's traces. Start resumes the same event, column and filter configuration; close and recreate the trace to change those selections.

```text
@TraceName nvarchar(128) = null,
@TraceID int = null
```

TraceID is the native SQL Server trace ID. Configuration and Start require the creator session/login; explicit Stop/Close selectors can target another creator when permissions allow. Native SQL Trace permissions are not granted by these procedures. See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md).
