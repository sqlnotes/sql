# z.usp_TraceRegisterCollector

[Trace](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_TraceRegisterCollector.sql)

## Purpose and behavior

Clean abandoned runs, then obtain or create this session/login generation's Building registry row. Different sessions register independent UUIDs and may use the same logical names. Briefly serialize admission/cleanup with a database application lock; this is not a singleton collector restriction. Set session context key Schema z.TraceCollector.UUID before committing registry changes. Reject ambient transactions.

## Parameters and defaults

```text
@CollectorUUID uniqueidentifier output
```

## Results, permissions and limits

CollectorUUID output; no defined result set. Usually called through TraceCreate. Requires full server session/request visibility and registry access. Do not make the reserved context key read-only.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for run ownership, schema compatibility and known transport limits.
