# z.usp_TraceAddEvents

[Trace](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_TraceAddEvents.sql)

Chooses which kinds of SQL Server activity a trace will capture, such as `SQL:BatchCompleted`, and which information to record for each event. Configure these selections before starting the trace for the first time.

`@EventList` is a comma-separated list of complete names from `z.v_TraceEvent`. `@EventColumnList` chooses columns from `z.v_TraceColumn`; NULL keeps the current column selection and `all` requests all supported columns. A NULL event list makes no change. Spaces and duplicates are removed; unknown or empty entries are rejected. `SPID` is retained where the event supports it. Event names must be explicit; `all` applies only to columns.

```text
@TraceName nvarchar(128) = null,
@TraceID int = null,
@EventList nvarchar(max) = null,
@EventColumnList nvarchar(max) = null
```

TraceID is the native SQL Server trace ID. Configuration APIs require a stopped trace created by the current session/login; name and ID selectors, when both supplied, must match the same registration. Native SQL Trace permissions are not granted by these procedures. See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md).

Events, columns and filters must be configured before native event binding begins on the first Start attempt. After that, Close/Create is required to change them; Stop/Start resumes the same fixed configuration.
