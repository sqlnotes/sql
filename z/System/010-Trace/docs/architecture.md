# Trace architecture

[Subsystem](readme.md) | [Object index](reference/readme.md)

Trace connects SQL Server's event capture to database tables and optional stored-procedure callbacks. The creating connection owns the trace configuration and collection workflow. Each definition is independent, so choose its events and destination before starting capture.

## Native traces

Each `z.Trace` registration describes one SQL Server trace; `TraceID` is its server-assigned ID. Create prepares it stopped. Configure events, output columns and filters before the first Start attempt. Once applying those selections begins, changing them requires Close/Create. Stop pauses capture and Start resumes the same configuration. Callbacks and destination metadata can be changed while stopped. Traces have no scheduled stop time and are not automatically replaced on restart.

Run configuration, create, start, stop, close, collection and abandoned cleanup outside a transaction. These procedures reject an active caller transaction with `XACT_ABORT ON`, making it uncommittable. Native SQL Trace actions cannot be rolled back with metadata.

Each trace has its own receiving table and callbacks. SQL Server evaluates its filters: predicates on one column follow their configured `and`/`or` operators, while different columns combine with `AND`. Filters are not one global boolean expression ordered across all columns. Native SQL Trace comparison and collation rules apply.

## Collection and transactions

`z.usp_TraceCollectAndClose` reads this connection's running traces in turn and stores received events in their destination tables. Capture continues while collection reads events. Each insert and its callback share a transaction, so their database changes succeed or fail together. Use one dedicated connection without MARS.

Received work commits in batches, approximately every five seconds by default, or sooner when an optional event limit is reached. Reads, callbacks and scheduling can extend both a commit window and the requested total duration; locks remain held until commit. Normal completion commits pending work. A failed batch rolls back, but earlier commits remain and consumed native events cannot be recovered through rollback.

Callbacks receive named `@TraceSequence`, `@TraceID` and `@EventName` arguments and must not change transaction ownership. A callback registered for `all` takes precedence over event-specific registrations.

An externally stopped or closed trace normally leaves polling; other selected traces continue. If a concurrent native read error leaves the pending transaction uncommittable, collection rolls it back and preserves the original error. Normal completion closes the originally selected native traces and removes their configuration, retaining destination data. Error cleanup attempts the same and rethrows the original error. Cancellation may require cleanup after disconnect.

## Abandoned traces

`z.usp_TraceCleanup` removes framework traces whose creating connection has ended. An idle connection keeps its traces, while a new connection reusing an old session ID does not inherit them. Cleanup uses both the recorded session ID and login time and never targets arbitrary unregistered server traces. Use the framework lifecycle APIs to keep registrations synchronized.

z.usp_TraceCreate calls cleanup automatically before allocating a trace; operators can also invoke it explicitly. Cleanup requires full server session visibility. It never infers abandonment from the absence of an active request.

## Installation and transition

System supplies sequence, partition and semaphore foundations. Trace installs before Monitoring, which owns diagnostic presets, tables and snapshot callbacks. Installation does not start capture. Internal configuration tables have guarded baselines and no foreign keys.

When upgrading the former shared-collector design, stop collector calls for the maintenance window. The installer closes registered legacy traces and clears their old configuration, while retaining diagnostic receiving tables and data. Directly running modules without the installer does not perform that transition; the baseline rejects populated legacy state instead of guessing which traces to close. Native cleanup failures stop installation for a safe retry.

## Transport limits

Bounded rowset reads previously lost selected events on the tested engine even with zero reported drops. This receiver remains best effort; normal completion does not certify completeness. Polling several traces, native waits and callbacks can extend processing and the optional total duration. Snapshot callbacks inspect state when processed, not at the original event time. No strict latency guarantee is made. The backend remains T-SQL SQL Trace without files, linked servers, SQLCLR or helper receivers.
