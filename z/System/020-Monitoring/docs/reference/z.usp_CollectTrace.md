# z.usp_CollectTrace

[Monitoring](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_CollectTrace.sql)

## Purpose and behavior

Build/enable four logical presets: BlockedProcessReport, LongRunningQueryTrace, TraceErrors, FileAutoGrowTrace. Exclude collector SPID where configured; long-running duration threshold is 1300000 microseconds. Register all-event snapshot callbacks through z.usp_TraceSetTrigger for blocking and growth, then invoke z.usp_TraceCollectAndClose with its long default duration. Create/Start allocate no native trace. Collect merges the enabled logical definitions into one physical trace for this session and keeps their filters/destinations independent.

## Parameters and defaults

None.

These are the source-declared types and defaults.

## Results, permissions, and limits

No parameters or defined result set. Requires trace, receiving-table, callback, and snapshot access. Does not configure blocked-process-report server threshold. Presets pass complete event names to the Trace framework, including separate SP:Completed and SP:StmtCompleted entries.

## Dependencies

Direct SQL object dependencies: `z.TraceBlockedProcessReport`, `z.TraceError`, `z.TraceFileAutoGrow`, `z.TraceLongRunningQuery`, `z.usp_TraceSetTrigger`, `z.usp_TakeSnapshotActiveSessionsForBlockedProcessReport`, `z.usp_TakeSnapshotActiveSessionsForFileAutoGrow`, `z.usp_TraceAddEvents`, `z.usp_TraceAddFilter`, `z.usp_TraceCollectAndClose`, `z.usp_TraceCreate`, `z.usp_TraceStart`, `z.usp_TraceCleanupCollectors`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.

Startup first calls z.usp_TraceCleanupCollectors. TraceCreate registers this session's Building run without native allocation. Other sessions register and collect independently, including identical logical names. Configuration freezes during Collect; normal completion removes the run configuration and retains event/snapshot data.

Cleanup preserves idle Building runs while their original session exists, and Collecting runs while the original owner has any active request. Full server session/request visibility and a dedicated connection/database are required. Callbacks receive named TraceSequence, logical TraceID and EventName parameters; all-event callbacks override event-specific registrations.

The retained one-frame bounded rowset backend can lose unread events despite zero native drops. Merging does not establish losslessness, a callback deadline or a performance winner. Raw saving and parsing are not separated.
