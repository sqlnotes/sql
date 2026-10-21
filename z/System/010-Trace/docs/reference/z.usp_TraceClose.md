# z.usp_TraceClose

[Trace](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_TraceClose.sql)

## Purpose and behavior

In Building, remove selected current-run logical definitions and their configuration. With neither selector, close the whole run. In Collecting, individual selectors are rejected: close the whole run and its single physical trace. Verify native expiry/start-time identity before stopping/closing; preserve a reused native ID and ownership for review. Remove output bindings, event selections, filters, callbacks and definitions transactionally, then release an empty registry/context. Destination tables and event data remain. Ambient transactions are rejected.

## Parameters and defaults

```text
@TraceName nvarchar(128) = null,
@TraceID int = null
```

## Results, permissions and limits

No defined result set. Native cleanup is not rolled back with metadata. On failure, retained ownership permits cleanup/review. Requires native trace privileges when a physical trace exists.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for run ownership, schema compatibility and known transport limits.
