# z.usp_TraceSetTrigger

[Trace](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_TraceSetTrigger.sql)

Register a stored-procedure callback for all or one selected event on a stopped trace. EventName all overrides event-specific callbacks. The procedure must be in the current database and accept named @TraceSequence, @TraceID and @EventName. It runs after the insert in the same transaction and must not commit/rollback that transaction.

```text
@TraceName nvarchar(128) = null,
@TraceID int = null,
@EventName nvarchar(128) = N'all',
@ProcedureName nvarchar(517)
```

TraceID is the native SQL Server trace ID. Configuration APIs require a stopped trace created by the current session/login; name and ID selectors, when both supplied, must match the same registration. Native SQL Trace permissions are not granted by these procedures. See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md).
