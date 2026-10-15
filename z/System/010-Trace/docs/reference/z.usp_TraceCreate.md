# z.usp_TraceCreate

[Trace](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_TraceCreate.sql)

## Purpose and behavior

Delete unavailable metadata rows. Null TraceName returns. Reject a running matching name; close a stopped matching trace created by another SPID. Reuse a stopped current-session trace and conditionally update Description/ReceivingTable, or create a SQL Trace rowset (options=1) and merge z.Trace. Default receiving table is z.[Trace_<name>]. The receiving table is created later by collection. No explicit transaction protects native trace creation plus metadata.

## Parameters and defaults

```text
@TraceName nvarchar(128) = null,@Description nvarchar(max) = null,@ReceivingTable nvarchar(128) = null,@TraceID int = null output
```

These are the source-declared types and defaults.

## Results, permissions, and limits

TraceID output; no defined result set. Requires ALTER TRACE and metadata writes. On repeated stopped trace, ReceivingTable updates only when Description is non-null.

## Dependencies

Direct SQL object dependencies: `z.Trace`, `z.usp_TraceClose`, `z.v_Trace`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
