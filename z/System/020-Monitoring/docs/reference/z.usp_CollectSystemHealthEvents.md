# z.usp_CollectSystemHealthEvents

[Monitoring](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_CollectSystemHealthEvents.sql)

## Purpose and behavior

Keeps selected events from SQL Server's `system_health` ring buffer in `z.SystemHealthEvent` for later investigation. Run it periodically before older buffer contents are overwritten. It keeps the original event XML and UTC event time, skips the noisy event types listed below, and leaves previously stored events intact.

The collector reads an already-running `system_health` session; it does not create, start or change it. A missing/stopped session or missing ring-buffer target produces no new rows. This replaces `z.usp_CheckSystemHealthTrace`; update external jobs and callers to the new name. Monitoring's [post cleanup](../../post/DeprecatedObject.sql) removes the retired procedure.

Within each input snapshot, the collector keeps one row per
(EventDateUTC, EventName, EventHash) before checking the stored keys. Repeated
source events therefore do not cause duplicate inserts in a single call. The
decoder continues to return every source event. Concurrent calls are not
serialized and can still race against the destination primary key.

Excluded event names are `security_error_ring_buffer_recorded`,
`connectivity_ring_buffer_recorded`,
`scheduler_monitor_system_health_ring_buffer_recorded`,
`sp_server_diagnostics_component_result`, `memory_broker_ring_buffer_recorded`,
`wait_info`, and `scheduler_monitor_deadlock_ring_buffer_recorded`.
Filtering applies to new collection; it does not delete stored events or change
the server's system_health session.

## Parameters and defaults

None.

## Results, permissions, and limits

Returns no rows; query `z.SystemHealthEvent` for collected events. Only events still present in the ring buffer can be collected. It starts no transaction of its own, and insert errors propagate.

## Dependencies

Direct SQL object dependencies: `z.SystemHealthEvent`, `z.fn_ExtractSystemHealthEvent`, `sys.dm_xe_sessions`, `sys.dm_xe_session_targets`. Requires destination access and server DMV visibility.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
