# z.usp_CollectTrace

[Monitoring](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_CollectTrace.sql)

Starts diagnostic collection for blocked-process reports, slow queries, SQL errors and database-file growth. It saves events in `z.TraceBlockedProcessReport`, `z.TraceLongRunningQuery`, `z.TraceError` and `z.TraceFileAutoGrow`, with related active-request snapshots for blocking and growth. Use it on a dedicated connection when you want these four Monitoring presets together.

This is a long-running synchronous call, not a background-job launcher. It uses four native SQL traces with no scheduled stop time and collects them on the calling connection. All four exclude the collector's own session; the slow-query preset captures durations greater than 1.3 seconds. Installation does not start collection or configure the server's blocked-process threshold.

`@TransactionDurationInSec int = 5` is a positive commit window in seconds, not the total collection duration. Pending event transactions span reads and idle waits, and blocking can extend the window.

Collected diagnostic rows remain available after the traces close. The procedure cleans up abandoned framework traces before starting, and closes its selected traces/configuration when collection completes. Cleanup preserves traces whose original owner session is still connected, even if idle.

Dependencies include z.TraceBlockedProcessReport, z.TraceError, z.TraceFileAutoGrow, z.TraceLongRunningQuery, z.usp_TraceCleanup, z.usp_TraceCreate, z.usp_TraceAddEvents, z.usp_TraceAddFilter, z.usp_TraceSetTrigger, z.usp_TraceStart, z.usp_TraceCollectAndClose, z.usp_TakeSnapshotActiveSessionsForBlockedProcessReport and z.usp_TakeSnapshotActiveSessionsForFileAutoGrow. Native trace, destination and callback privileges are required.

Callbacks accept named TraceSequence, native TraceID and EventName, run in the event transaction and must not change its ownership. Snapshot state reflects processing time. Bounded native reads have known event-loss limits; successful completion does not certify completeness. See [Trace architecture](../../../010-Trace/docs/architecture.md).

If startup fails before collection begins, cleanup closes only traces newly created by this invocation and rethrows the original error. Existing caller-owned traces are preserved by that startup cleanup. Use a dedicated connection: normal collection selects all running traces created by that session.
