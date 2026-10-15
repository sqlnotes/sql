# z.usp_TakeSnapshotActiveSessionsForFileAutoGrow

[Trace](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_TakeSnapshotActiveSessionsForFileAutoGrow.sql)

## Purpose and behavior

Append z.v_ActiveSessions rows into z.TraceFileAutoGrowActiveSessions correlated by TraceSequence. QueryPlan is intentionally not copied. Use read uncommitted and xact_abort; no explicit transaction. TraceID and EventName are accepted for callback compatibility but unused. No event existence check or throttling is applied.

## Parameters and defaults

```text
@TraceSequence bigint,  @TraceID int = null,  @EventName nvarchar(128) = null
```

These are the source-declared types and defaults.

## Results, permissions, and limits

No defined result set. Requires snapshot insert and sufficient DMV visibility. Snapshot reflects collection-time requests, not necessarily event-time requests.

## Dependencies

Direct SQL object dependencies: `z.TraceFileAutoGrowActiveSessions`, `z.v_ActiveSessions`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
