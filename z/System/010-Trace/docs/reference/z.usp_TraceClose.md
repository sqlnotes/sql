# z.usp_TraceClose

[Trace](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_TraceClose.sql)

## Purpose and behavior

Remove selected logical definitions and their event/column/filter/callback configuration regardless of caller ownership, including during collection. TraceID is the logical z.Trace ID. An explicit TraceName matches that name across runs; with neither selector, close the current context run. Unselected enabled definitions retain their shared native generations. If none remain enabled in an affected run, stop/close all its registered native generations. Destination data remains.

## Parameters and defaults

```text
@TraceName nvarchar(128) = null,
@TraceID int = null
```

## Results, permissions and limits

No defined result set. No caller-ownership check is performed. Requires metadata permissions and ALTER TRACE for native cleanup. Ambient transactions are rejected. Native identity tags distinguish the selected logical resources from a recycled native ID; a stale selected mapping is removed without closing a different native generation. Already stopped or closed resources are accepted. The receiver can finish its own registry cleanup if it was active when another session closed its last definition.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for run ownership, schema compatibility and known transport limits.
