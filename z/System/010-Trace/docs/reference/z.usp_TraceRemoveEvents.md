# z.usp_TraceRemoveEvents

[Trace](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_TraceRemoveEvents.sql)

Removes kinds of activity from a trace's planned capture. Supply complete event names in `@EventList`; `all` removes every configured event, while NULL removes none. Matching columns and event callbacks are removed with them, while previously collected data is retained.

```text
@TraceName nvarchar(128) = null,
@TraceID int = null,
@EventList nvarchar(max) = null
```

TraceID is the native SQL Server trace ID. Configuration APIs require a stopped trace created by the current session/login; name and ID selectors, when both supplied, must match the same registration. Native SQL Trace permissions are not granted by these procedures. See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md).

Events, columns and filters must be configured before native event binding begins on the first Start attempt. After that, Close/Create is required to change them; Stop/Start resumes the same fixed configuration.
