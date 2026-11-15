# z.usp_TraceRemoveTrigger

[Trace](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_TraceRemoveTrigger.sql)

Remove callback registrations from one stopped trace. Calling with `@EventName = N'all'` or `@EventName = null` removes all callbacks for the trace; otherwise removes callbacks matching the specified event name. Destination data is unaffected.

```text
@TraceName nvarchar(128) = null,
@TraceID int = null,
@EventName nvarchar(128) = N'all'
```

TraceID is the native SQL Server trace ID. Configuration APIs require a stopped trace created by the current session/login; name and ID selectors, when both supplied, must match the same registration. Native SQL Trace permissions are not granted by these procedures. See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md).
