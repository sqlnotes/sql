# z.usp_TraceRemoveTrigger

[Trace](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_TraceRemoveTrigger.sql)

Stops invoking a callback for a stopped trace without deleting collected events. `@EventName` selects the callback registration to remove: pass an event name for that event's callback, or `all` (the default) for the trace-wide `all` callback registration; NULL removes none. The callback procedure itself is not dropped.

```text
@TraceName nvarchar(128) = null,
@TraceID int = null,
@EventName nvarchar(128) = N'all'
```

TraceID is the native SQL Server trace ID. Configuration APIs require a stopped trace created by the current session/login; name and ID selectors, when both supplied, must match the same registration. Native SQL Trace permissions are not granted by these procedures. See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md).
