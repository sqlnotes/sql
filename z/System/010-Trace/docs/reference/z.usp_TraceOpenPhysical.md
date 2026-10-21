# z.usp_TraceOpenPhysical

[Trace](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_TraceOpenPhysical.sql)

## Purpose and behavior

Internal collection helper. Require an owned Building run with enabled logical definitions, each selecting at least one event. Freeze the run to Collecting, allocate/register exactly one native rowset trace, and enable the union of selected output bindings and filter inputs. Add SPID where supported. Push down only an identical single = or <> SPID predicate present in every enabled definition; evaluate all logical predicates locally as well. Start the physical trace and record its generation.

On setup failure, attempt generation-safe cleanup and rethrow. Native allocation is not transactional; cancellation between allocation and registration can leave an unregistered resource. Call through TraceCollectAndClose for normal operation.

## Parameters and defaults

```text
@NativeTraceID int output
```

## Results, permissions and limits

NativeTraceID output identifies sys.traces.id, not a logical ID. Reject ambient transactions. Requires ALTER TRACE, native catalog visibility and registry access. No raw/parser separation or larger-frame reader is introduced.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for run ownership, schema compatibility and known transport limits.
