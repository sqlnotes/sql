# z.usp_TraceStop

[Trace](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_TraceStop.sql)

## Purpose and behavior

Disable the selected logical definitions by setting IsEnabled=0, regardless of their owning session or Building/Collecting state. TraceID remains a logical z.Trace ID. An explicit TraceName applies to every matching name across runs; supplying TraceID selects that definition. With neither selector, act only on the current context run. Other enabled definitions keep their shared capture pool. When none remain enabled in an affected run, stop its native generations so the receiver can finish.

## Parameters and defaults

```text
@TraceName nvarchar(128) = null,
@TraceID int = null
```

## Results, permissions and limits

No defined result set. No caller-ownership check is performed. Requires metadata update permission and ALTER TRACE when native generations must stop. In-flight delivery can finish; later logical deliveries consult IsEnabled. Metadata updates participate in a caller transaction, but native stop operations cannot be rolled back. Start retains its ownership check.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for run ownership, schema compatibility and known transport limits.
