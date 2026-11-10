# z.usp_TraceCreate

[Trace](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_TraceCreate.sql)

Create a stopped native rowset trace without a scheduled stop time and return its native TraceID. Names are unique within the creator session/login. A stopped existing registration can be reused and its metadata updated; a running trace must first be stopped. A destination is a quoted two-part current-database table name fitting the registry limit; default z.Trace_<TraceName>. No receiving table is created here. Runs abandoned cleanup before allocation. Rejects ambient transactions.

```text
@TraceName nvarchar(128) = null,
@Description nvarchar(max) = null,
@ReceivingTable nvarchar(128) = null,
@TraceID int = null output
```

TraceID is the native SQL Server trace ID. Configuration and Start require the creator session/login; explicit Stop/Close selectors can target another creator when permissions allow. Native SQL Trace permissions are not granted by these procedures. See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md).
