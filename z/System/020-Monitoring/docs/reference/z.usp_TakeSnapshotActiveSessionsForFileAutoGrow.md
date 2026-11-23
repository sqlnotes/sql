# z.usp_TakeSnapshotActiveSessionsForFileAutoGrow

[Monitoring](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_TakeSnapshotActiveSessionsForFileAutoGrow.sql)

## Purpose and behavior

Saves the active requests visible when a file-growth event is processed. The saved rows in `z.TraceFileAutoGrowActiveSessions` can be joined to the growth event using `TraceSequence`, helping you investigate what was running around the growth. Query plans are not collected. Requests reflect snapshot time, which can be later than the event itself.

## Parameters and defaults

```text
@TraceSequence bigint,
@TraceID int = null,
@EventName nvarchar(128) = null
```

`@TraceSequence` identifies the related file-growth event. The Trace framework supplies `@TraceID` and `@EventName` for callback compatibility; this snapshot does not use them to select requests.

## Results, permissions, and limits

Returns no rows; query the saved snapshot table. Requires snapshot insert access and sufficient DMV visibility. It uses read-uncommitted visibility and starts no transaction of its own; the callback participates in its caller's transaction.

## Dependencies

Direct SQL object dependencies: `z.TraceFileAutoGrowActiveSessions`, `z.v_ActiveSessionsNoPlan`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
