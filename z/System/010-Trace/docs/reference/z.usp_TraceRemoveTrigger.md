# z.usp_TraceRemoveTrigger

[Trace](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_TraceRemoveTrigger.sql)

Remove a callback registration from one stopped trace. Destination data is unaffected.

```text
@TraceName nvarchar(128) = null,
@TraceID int = null,
@EventName nvarchar(128) = N'all'
```

TraceID is the native SQL Server trace ID. Configuration APIs require a stopped trace created by the current session/login; name and ID selectors, when both supplied, must match the same registration. Native SQL Trace permissions are not granted by these procedures. See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md).
