# z.usp_CollectTrace

[Monitoring](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_CollectTrace.sql)

Accepts @TransactionDurationInSec int = 5, a positive commit window in seconds passed to the collector. Pending event transactions span reads and idle waits; blocking work can extend this window. Run z.usp_TraceCleanup, then create/configure/start four native rowset traces: BlockedProcessReport, LongRunningQueryTrace, TraceErrors and FileAutoGrowTrace. Each has its own native events and filters, destination table and callbacks, without a scheduled stop time. All exclude the collector SPID; long-query duration is greater than 1300000 microseconds. Register blocking/growth snapshot callbacks and collect on one connection with the long default duration.

TraceCreate allocates a stopped native trace; TraceStart configures and starts it. Collection polls each trace with bounded reads and closes the selected traces/configuration on completion, retaining diagnostic data. Cleanup removes only framework traces whose original owner session/login is absent; idle connected owners are preserved. Installation does not start capture or configure the blocked-process threshold.

Dependencies include z.TraceBlockedProcessReport, z.TraceError, z.TraceFileAutoGrow, z.TraceLongRunningQuery, z.usp_TraceCleanup, z.usp_TraceCreate, z.usp_TraceAddEvents, z.usp_TraceAddFilter, z.usp_TraceSetTrigger, z.usp_TraceStart, z.usp_TraceCollectAndClose, z.usp_TakeSnapshotActiveSessionsForBlockedProcessReport and z.usp_TakeSnapshotActiveSessionsForFileAutoGrow. Native trace, destination and callback privileges are required.

Callbacks accept named TraceSequence, native TraceID and EventName, run in the event transaction and must not change its ownership. Snapshot state reflects processing time. Bounded native reads have known event-loss limits; successful completion does not certify completeness. See [Trace architecture](../../../010-Trace/docs/architecture.md).

If startup fails before collection begins, cleanup closes only traces newly created by this invocation and rethrows the original error. Existing caller-owned traces are preserved by that startup cleanup. Use a dedicated connection: normal collection selects all running traces created by that session.
