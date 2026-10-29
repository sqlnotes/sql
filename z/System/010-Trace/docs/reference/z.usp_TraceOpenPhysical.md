# z.usp_TraceOpenPhysical

[Trace](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_TraceOpenPhysical.sql)

## Purpose and behavior

Internal collection helper. Require an owned Building or Collecting run with enabled logical definitions. Freeze Building to Collecting once, then allocate/register one additional physical rowset generation. Enable the union of output bindings and filter inputs, plus SPID where supported and internal EventSequence. Every selected event must support EventSequence. Only an identical single = or <> SPID predicate in every enabled definition is pushed down. Start the generation and record its native identity.

On setup failure, attempt generation-safe cleanup and rethrow. Native allocation is not transactional; cancellation between allocation and registration can leave an unregistered resource. Call through TraceCollectAndClose for normal operation.

## Parameters and defaults

```text
@NativeTraceID int output,
@StopAt datetime = null
```

## Results, permissions and limits

NativeTraceID identifies sys.traces.id, not a logical ID. StopAt supplies a future native expiry for handoff; NULL preserves the legacy far-future expiry. Reject ambient transactions. Requires ALTER TRACE, native catalog visibility and registry access. Normal collection calls this helper repeatedly from one receiving connection.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for run ownership, schema compatibility and known transport limits.
