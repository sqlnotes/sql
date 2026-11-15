# z.usp_TakeSnapshotActiveSessionsForFileAutoGrow

[Monitoring](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_TakeSnapshotActiveSessionsForFileAutoGrow.sql)

## Purpose and behavior

Appends `z.v_ActiveSessionsNoPlan` rows into `z.TraceFileAutoGrowActiveSessions` correlated by `@TraceSequence`. Uses `read uncommitted` and `xact_abort on`; no explicit transaction. `@TraceID` and `@EventName` are accepted for callback compatibility.

## Parameters and defaults

```text
@TraceSequence bigint,
@TraceID int = null,
@EventName nvarchar(128) = null
```

## Results, permissions, and limits

No defined result set. Requires snapshot insert and sufficient DMV visibility.

## Dependencies

Direct SQL object dependencies: `z.TraceFileAutoGrowActiveSessions`, `z.v_ActiveSessionsNoPlan`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
