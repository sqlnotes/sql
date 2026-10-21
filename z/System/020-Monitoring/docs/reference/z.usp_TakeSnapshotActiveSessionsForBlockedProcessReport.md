# z.usp_TakeSnapshotActiveSessionsForBlockedProcessReport

[Monitoring](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_TakeSnapshotActiveSessionsForBlockedProcessReport.sql)

## Purpose and behavior

Append z.v_ActiveSessions rows into z.TraceBlockedProcessReportActiveSessions correlated by TraceSequence. QueryPlan is intentionally not copied. Use read uncommitted and xact_abort; no explicit transaction. TraceID and EventName are accepted for callback compatibility but unused. Return for unknown/null event text, text matching MScdc/vid_device_name/VIRTUAL_DEVICE/BACKUP/QRTZ, repeated TransactionID, or the rounded current second stored in session_context. Session-context markers are set before insert and survive transaction rollback.

## Parameters and defaults

```text
@TraceSequence bigint,
@TraceID int = null,
@EventName nvarchar(128) = null
```

These are the source-declared types and defaults.

## Results, permissions, and limits

No defined result set. Requires snapshot insert and sufficient DMV visibility. Snapshot reflects collection-time requests, not necessarily event-time requests.

## Dependencies

Direct SQL object dependencies: `z.TraceBlockedProcessReport`, `z.TraceBlockedProcessReportActiveSessions`, `z.v_ActiveSessions`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
