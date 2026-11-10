# z.usp_TraceAddEvents

[Trace](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_TraceAddEvents.sql)

Add explicit event selections and supported output bindings to one stopped native trace registration. NULL EventList does nothing; NULL EventColumnList inherits current columns. Retain SPID where supported. Lists trim/deduplicate complete catalog names and reject invalid entries. The whole value all is accepted for columns, not event names. TraceStart applies the metadata to the native trace.

```text
@TraceName nvarchar(128) = null,
@TraceID int = null,
@EventList nvarchar(max) = null,
@EventColumnList nvarchar(max) = null
```

TraceID is the native SQL Server trace ID. Configuration APIs require a stopped trace created by the current session/login; name and ID selectors, when both supplied, must match the same registration. Native SQL Trace permissions are not granted by these procedures. See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md).

Events, columns and filters must be configured before native event binding begins on the first Start attempt. After that, Close/Create is required to change them; Stop/Start resumes the same fixed configuration.
