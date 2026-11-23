# z.usp_TraceCreate

[Trace](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_TraceCreate.sql)

Creates a trace ready for configuration and returns its SQL Server trace ID through `@TraceID output`. It does not start capture or create the receiving table. Add the events, columns and filters you want, then call Start and CollectAndClose on the same connection.

`@TraceName` identifies the trace within your connection; NULL creates nothing. `@Description` records its purpose. `@ReceivingTable` selects a two-part table name in the current database, defaulting to `z.Trace_<TraceName>`. The complete quoted name must fit the registry's 128-character limit. A stopped trace with the same name can be reused and updated; a running trace must first be stopped. Run outside an existing transaction.

```text
@TraceName nvarchar(128) = null,
@Description nvarchar(max) = null,
@ReceivingTable nvarchar(128) = null,
@TraceID int = null output
```

TraceID is the native SQL Server trace ID. Configuration and Start require the creator session/login; explicit Stop/Close selectors can target another creator when permissions allow. Native SQL Trace permissions are not granted by these procedures. See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md).
