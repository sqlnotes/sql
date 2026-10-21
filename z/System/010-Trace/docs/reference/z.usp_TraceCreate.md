# z.usp_TraceCreate

[Trace](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_TraceCreate.sql)

## Purpose and behavior

Create or reuse a run-owned logical definition and return its logical identity TraceID. Register the current session as a Building run using the reserved UUID context. Allocate no native trace. Names are unique within the run; another session can use the same name. A supplied receiving table must be a current-database two-part name in an existing schema, and its quoted form must fit 128 characters. If omitted for a new definition, use z.Trace_<TraceName>. No destination table is created here. NULL TraceName returns. Supplied Description and ReceivingTable update independently on a reusable disabled definition. Enabled definitions must be stopped before changing this metadata. Ambient transactions are rejected.

## Parameters and defaults

```text
@TraceName nvarchar(128) = null,
@Description nvarchar(max) = null,
@ReceivingTable nvarchar(128) = null,
@TraceID int = null output
```

## Results, permissions and limits

TraceID output; no defined result set. Initial schema/API redesign has no migration. Use a fresh installation or explicitly recreate existing development tables.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for run ownership, schema compatibility and known transport limits.
