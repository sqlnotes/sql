# z.usp_TraceStart

[Trace](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_TraceStart.sql)

Apply event bindings and typed native filters to each selected stopped trace, then start that same native trace. Native event bindings are added idempotently; native filters are cleared and reapplied. Once native event binding begins, events/columns/filters are fixed until Close/Create, including after a partially failed Start. A running trace is not restarted. Requires the creator session/login and at least one selected event; rejects ambient transactions.

```text
@TraceName nvarchar(128) = null,
@TraceID int = null
```

TraceID is the native SQL Server trace ID. Configuration and Start require the creator session/login; explicit Stop/Close selectors can target another creator when permissions allow. Native SQL Trace permissions are not granted by these procedures. See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md).
