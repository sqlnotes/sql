# z.usp_TakeSnapshotActiveSessions

[Monitoring](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_TakeSnapshotActiveSessions.sql)

## Purpose and behavior

Insert current z.v_ActiveSessions rows into z.ActiveSessions; SnapshotDate and ActiveSessionID use table defaults. Repeated calls append snapshots; no explicit transaction or catch is used.

## Parameters and defaults

None.

These are the source-declared types and defaults.

## Results, permissions, and limits

No defined result set. Requires insert access and sufficient DMV visibility.

## Dependencies

Direct SQL object dependencies: `z.ActiveSessions`, `z.v_ActiveSessions`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
