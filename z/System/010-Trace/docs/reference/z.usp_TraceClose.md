# z.usp_TraceClose

[Trace](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_TraceClose.sql)

Stop and close selected registered native traces and remove their event/column/filter/callback configuration. Retain receiving tables and collected data. Explicit selectors may target another creator when SQL permissions allow; no selector means the current session/login. Already-closed traces are normal. Actions use the registered TraceID under its registration lock. Rejects ambient transactions.

```text
@TraceName nvarchar(128) = null,
@TraceID int = null,
@ExpectedCreatorSessionID int = null,
@ExpectedCreatorLoginTime datetime = null
```

TraceID is the native SQL Server trace ID. Configuration and Start require the creator session/login; explicit Stop/Close selectors can target another creator when permissions allow. Native SQL Trace permissions are not granted by these procedures. See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md).

The optional Expected parameters guard a saved selection against a replacement registration. Supply creator session ID/login together. The collector supplies these internally during cleanup.
