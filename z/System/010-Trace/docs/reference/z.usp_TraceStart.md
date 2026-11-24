# z.usp_TraceStart

[Trace](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_TraceStart.sql)

Starts capturing activity for the selected trace using its configured events, columns and filters. Run it on the connection that created the trace, outside an existing transaction. At least one event must be selected. Starting an already running trace does not restart it.

Configure events, columns and filters before the first Start attempt. Once applying that configuration begins, it is fixed even if Start only partly succeeds: close and recreate the trace to change it. Stop followed by Start resumes capture with the same configuration. Starting capture does not collect events into the destination table; use CollectAndClose for that.

```text
@TraceName nvarchar(128) = null,
@TraceID int = null
```

TraceID is the native SQL Server trace ID. Configuration and Start require the creator session/login; explicit Stop/Close selectors can target another creator when permissions allow. Native SQL Trace permissions are not granted by these procedures. See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md).
