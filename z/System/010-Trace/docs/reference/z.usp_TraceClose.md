# z.usp_TraceClose

[Trace](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_TraceClose.sql)

Finishes a trace and removes its capture configuration and callbacks. The receiving table and all collected rows remain available. Closing an already closed trace is a normal outcome.

Select by `@TraceName` or `@TraceID`; explicit selectors can address another connection's trace when permissions allow. Omit both to close this connection's traces. Run outside an existing transaction.

```text
@TraceName nvarchar(128) = null,
@TraceID int = null,
@ExpectedCreatorSessionID int = null,
@ExpectedCreatorLoginTime datetime = null
```

TraceID is the native SQL Server trace ID. Configuration and Start require the creator session/login; explicit Stop/Close selectors can target another creator when permissions allow. Native SQL Trace permissions are not granted by these procedures. See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md).

The optional Expected parameters guard a saved selection against a replacement registration. Supply creator session ID/login together. The collector supplies these internally during cleanup.
