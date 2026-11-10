# z.usp_TraceRemoveColumns

[Trace](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_TraceRemoveColumns.sql)

Remove selected output columns from one stopped native trace registration while retaining required SPID bindings. TraceStart applies the remaining bindings.

```text
@TraceName nvarchar(128) = null,
@TraceID int = null,
@EventColumnList nvarchar(max) = null
```

TraceID is the native SQL Server trace ID. Configuration APIs require a stopped trace created by the current session/login; name and ID selectors, when both supplied, must match the same registration. Native SQL Trace permissions are not granted by these procedures. See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md).

Events, columns and filters must be configured before native event binding begins on the first Start attempt. After that, Close/Create is required to change them; Stop/Start resumes the same fixed configuration.
