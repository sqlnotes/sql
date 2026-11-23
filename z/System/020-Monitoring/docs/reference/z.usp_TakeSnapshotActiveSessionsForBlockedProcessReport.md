# z.usp_TakeSnapshotActiveSessionsForBlockedProcessReport

[Monitoring](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_TakeSnapshotActiveSessionsForBlockedProcessReport.sql)

## Purpose and behavior

Saves active-request details to help investigate a blocked-process report. Rows are stored in `z.TraceBlockedProcessReportActiveSessions` and linked to the report by `TraceSequence`. Query plans are omitted. The snapshot shows requests visible when the callback runs, which may differ from the requests present when the blocking event occurred.

To avoid noisy or repeated snapshots, it skips reports with missing event text, text matching `MScdc`, `vid_device_name`, `VIRTUAL_DEVICE`, `BACKUP` or `QRTZ`, the same transaction ID as the session's last snapshot, or another snapshot in the same rounded current second. Its per-session suppression markers survive rollback, so a rolled-back snapshot can still suppress a repeated attempt in that session.

## Parameters and defaults

```text
@TraceSequence bigint,
@TraceID int = null,
@EventName nvarchar(128) = null
```

`@TraceSequence` identifies the report being investigated. `@TraceID` and `@EventName` are accepted for Trace callback compatibility but do not change the snapshot selection.

## Results, permissions, and limits

Returns no rows; query the saved snapshot table and join to the report on `TraceSequence`. Requires snapshot insert access and sufficient DMV visibility. It uses read-uncommitted visibility, starts no transaction of its own and participates in the callback's transaction.

## Dependencies

Direct SQL object dependencies: `z.TraceBlockedProcessReport`, `z.TraceBlockedProcessReportActiveSessions`, `z.v_ActiveSessions`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
