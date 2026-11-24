# z.usp_TakeSnapshotActiveSessions

[Monitoring](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_TakeSnapshotActiveSessions.sql)

## Purpose and behavior

Saves the currently visible active requests in `z.ActiveSessions` so you can inspect them after the requests finish. It captures the requests shown by `z.v_ActiveSessions`, excluding the collecting session. Each call adds another snapshot rather than replacing earlier ones. It is a picture of collection time, not a complete session history.

## Parameters and defaults

None.

## Results, permissions, and limits

Returns no rows; query `z.ActiveSessions` for saved snapshots and use `SnapshotDate` to identify the collection time. Requires insert access and enough DMV visibility to see the requests of interest. The procedure does not start a transaction of its own; insert errors propagate.

## Dependencies

Direct SQL object dependencies: `z.ActiveSessions`, `z.v_ActiveSessions`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
