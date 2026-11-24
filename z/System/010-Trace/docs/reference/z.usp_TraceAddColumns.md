# z.usp_TraceAddColumns

[Trace](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_TraceAddColumns.sql)

Adds information to record for the trace's configured events, such as query text, duration or start time. Call it while configuring a stopped trace, before the first Start attempt.

`@EventColumnList` contains complete comma-separated names from `z.v_TraceColumn`; use `all` for all supported columns. Only columns supported by each selected event can be added. The columns take effect when the trace starts.

```text
@TraceName nvarchar(128) = null,
@TraceID int = null,
@EventColumnList nvarchar(max) = null
```

TraceID is the native SQL Server trace ID. Configuration APIs require a stopped trace created by the current session/login; name and ID selectors, when both supplied, must match the same registration. Native SQL Trace permissions are not granted by these procedures. See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md).

Events, columns and filters must be configured before native event binding begins on the first Start attempt. After that, Close/Create is required to change them; Stop/Start resumes the same fixed configuration.
