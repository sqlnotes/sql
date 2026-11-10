# z.usp_TraceRemoveEvents

[Trace](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_TraceRemoveEvents.sql)

Remove selected events and their column bindings from one stopped native trace registration. The whole value all selects all configured events. TraceStart applies remaining configuration.

```text
@TraceName nvarchar(128) = null,
@TraceID int = null,
@EventList nvarchar(max) = null
```

TraceID is the native SQL Server trace ID. Configuration APIs require a stopped trace created by the current session/login; name and ID selectors, when both supplied, must match the same registration. Native SQL Trace permissions are not granted by these procedures. See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md).

Events, columns and filters must be configured before native event binding begins on the first Start attempt. After that, Close/Create is required to change them; Stop/Start resumes the same fixed configuration.
