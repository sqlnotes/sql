# z.usp_CollectSystemHealthEvents

[Monitoring](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_CollectSystemHealthEvents.sql)

## Purpose and behavior

Read the running system_health ring_buffer target, pass its XML to z.fn_ExtractSystemHealthEvent(@TargetData), exclude five noisy event names, and insert keys absent from z.SystemHealthEvent. The decoder supplies UTC EventDateUTC and MD5 EventHash. An absent/stopped session or missing target yields no rows. It has no explicit transaction or catch. This replaces z.usp_CheckSystemHealthTrace; update external jobs and callers to the new name. Central deployment cleanup removes the retired procedure.

Within each input snapshot, the collector keeps one row per
(EventDateUTC, EventName, EventHash) before checking the stored keys. Repeated
source events therefore do not cause duplicate inserts in a single call. The
decoder continues to return every source event. Concurrent calls are not
serialized and can still race against the destination primary key.

## Parameters and defaults

None.

These are the source-declared types and defaults.

## Results, permissions, and limits

No defined result set. Existing stored rows are retained; ring-buffer data only is collected.

## Dependencies

Direct SQL object dependencies: `z.SystemHealthEvent`, `z.fn_ExtractSystemHealthEvent`, `sys.dm_xe_sessions`, `sys.dm_xe_session_targets`. Requires destination access and server DMV visibility.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
