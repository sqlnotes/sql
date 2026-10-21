# z.usp_TraceAssertOwner

[Trace](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_TraceAssertOwner.sql)

## Purpose and behavior

Require a registered collector matching the current UUID context, session ID and login generation. Reject an explicitly selected logical TraceID belonging to another UUID. Names are run-local; an identically named definition in another session does not prevent use of the name. Callers still resolve selector intersections and enforce Building/Collecting state.

## Parameters and defaults

```text
@TraceName nvarchar(128) = null,
@TraceID int = null
```

## Results, permissions and limits

No defined result set; throws when ownership fails. Does not allocate native traces, modify state or prove native generation ownership.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for run ownership, schema compatibility and known transport limits.
