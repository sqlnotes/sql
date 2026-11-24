# z.usp_TraceSetTrigger

[Trace](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_TraceSetTrigger.sql)

Runs a stored procedure after a received event is recorded, for example to take a diagnostic snapshot. Despite the name, this registers a callback rather than creating a DML trigger. Configure it while the trace is stopped.

`@ProcedureName` identifies the callback in the current database. `@EventName` chooses one event, or `all` for every event; an `all` registration takes precedence over event-specific callbacks. The procedure must accept named `@TraceSequence`, `@TraceID` and `@EventName` arguments. It shares the event's transaction and must not commit or roll it back.

```text
@TraceName nvarchar(128) = null,
@TraceID int = null,
@EventName nvarchar(128) = N'all',
@ProcedureName nvarchar(517)
```

TraceID is the native SQL Server trace ID. Configuration APIs require a stopped trace created by the current session/login; name and ID selectors, when both supplied, must match the same registration. Native SQL Trace permissions are not granted by these procedures. See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md).
