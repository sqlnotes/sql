# z.usp_CollectTrace

[Trace](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_CollectTrace.sql)

## Purpose and behavior

Replace/start four presets: BlockedProcessReport, LongRunningQueryTrace, TraceErrors, FileAutoGrowTrace. Exclude collector SPID where configured; long-running duration threshold is 1300000 microseconds. Register all-event snapshot callbacks for blocking and growth, then invoke z.usp_TraceCollectAndClose with its long default duration.

## Parameters and defaults

None.

These are the source-declared types and defaults.

## Results, permissions, and limits

No parameters or defined result set. Requires trace, receiving-table, callback, and snapshot access. Does not configure blocked-process-report server threshold. Preset SP:CompletedSP:StmtCompleted is a malformed concatenated event token.

## Dependencies

Direct SQL object dependencies: `z.TraceBlockedProcessReport`, `z.TraceError`, `z.TraceFileAutoGrow`, `z.TraceLongRunningQuery`, `z.TraceTrigger`, `z.usp_TakeSnapshotActiveSessionsForBlockedProcessReport`, `z.usp_TakeSnapshotActiveSessionsForFileAutoGrow`, `z.usp_TraceAddEvents`, `z.usp_TraceAddFilter`, `z.usp_TraceClose`, `z.usp_TraceCollectAndClose`, `z.usp_TraceCreate`, `z.usp_TraceStart`, `z.usp_TraceStop`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
