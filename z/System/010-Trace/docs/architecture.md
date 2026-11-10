# Trace architecture

[Subsystem](readme.md) | [Object index](reference/readme.md)

## Native traces

Each z.Trace registration identifies one native SQL Server rowset trace. TraceID is the native ID. Create allocates it stopped with no scheduled stop time. Configure events, output columns and filters before the first Start. Start applies that configuration to the same native trace; once native event binding begins, changing those selections requires Close/Create. Stop pauses capture and Start resumes the same trace with its fixed native configuration. Callbacks and destination metadata can be changed while stopped. There is no shared capture, local filter routing or automatic trace replacement. SQL Trace rowset SPID bindings cannot be removed; keeping the native configuration fixed avoids a destructive reset on explicit restart.

Configuration, create, start, stop, close, collection and abandoned cleanup reject existing caller transactions. Native SQL Trace actions cannot be rolled back with metadata.

Each trace has its own receiving table and callbacks. SQL Trace evaluates filters natively: predicates are grouped by column; different columns are combined with AND. Predicates within a column retain their configured AND/OR order. Native filtering semantics and collation apply.

## Collection and transactions

z.usp_TraceCollectAndClose selects running traces created by the current session/login, optionally restricted by name or native ID. One dedicated, non-MARS connection polls them in turn with bounded sp_trace_getdata reads (records = 1), then decodes an ordinal temporary buffer. It does not stop traces between reads. Every complete decoded event is inserted and its callback executes in the same transaction. EventClass is restored from the frame header when selected; fields reset for each event and datetime values use numeric parts.

Transactions span buffers, native reads and idle waits, committing pending work after a configurable window (5 seconds by default). The optional event cap defaults to NULL. Idle polling requests a 4 ms wait. Deadline checks occur before each read, after each event and before idle waits; blocking reads, callbacks and scheduling can extend the window. Locks persist until commit. Normal completion flushes a partial batch. An all-event callback overrides event-specific registrations. Callbacks receive named @TraceSequence, @TraceID and @EventName and must not change transaction ownership. Failed work rolls back the current batch; earlier commits remain. Native consumption cannot be rolled back.

An externally stopped or closed trace normally leaves polling; other selected traces continue. If a concurrent native read error leaves the pending transaction uncommittable, collection rolls it back and preserves the original error. Normal completion closes the originally selected native traces and removes their configuration, retaining destination data. Error cleanup attempts the same and rethrows the original error. Cancellation may require cleanup after disconnect.

## Abandoned traces

z.Trace records CreatorSessionID and CreatorLoginTime. z.usp_TraceCleanup removes registrations whose original session/login no longer exists, stopping and closing only a matching registered native rowset trace. An idle connected owner keeps its traces. A recycled session ID does not keep a previous owner's trace alive. Cleanup locks the registration and acts on its TraceID; unregistered SQL Server traces are outside its scope. There is no separate native ID or start-time tag. If a trace is closed outside the framework and its ID is reused while its registration remains, that reuse cannot be distinguished by ID alone. Use the framework lifecycle APIs to keep registrations synchronized.

TraceCreate and Monitoring startup call cleanup; operators can also invoke it explicitly. Cleanup requires full server session visibility. It never infers abandonment from the absence of an active request.

## Installation and transition

System supplies sequence, partition and semaphore foundations. Trace installs before Monitoring, which owns diagnostic presets, tables and snapshot callbacks. Installation does not start capture. Internal configuration tables have guarded baselines and no foreign keys.

Transition from the former collector schema requires stopped collection and empty old configuration and collector mappings before eligible baseline replay. The baseline rejects populated old state instead of guessing which server traces to close. Old collector helpers are retired. No version increment or universal upgrade migration is supplied; installations that skip baselines require an explicitly planned schema transition. Preserve diagnostic receiving tables and data.

## Transport limits

Bounded rowset reads previously lost selected events on the tested engine even with zero reported drops. This receiver remains best effort; normal completion does not certify completeness. Polling several traces, native waits and callbacks can extend processing and the optional total duration. Snapshot callbacks inspect state when processed, not at the original event time. No strict latency guarantee is made. The backend remains T-SQL SQL Trace without files, linked servers, SQLCLR or helper receivers.
