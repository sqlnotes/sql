# z.usp_TraceReleaseCollector

[Trace](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_TraceReleaseCollector.sql)

## Purpose and behavior

Remove this session/login owner's registry row and clear its UUID context only when no logical definitions or native mapping remain. Briefly serialize with admission/cleanup. Reject ambient transactions.

## Parameters and defaults

None.

## Results, permissions and limits

No defined result set. Does not close native traces or discard an unfinished run; normally called by TraceClose.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for run ownership, schema compatibility and known transport limits.
