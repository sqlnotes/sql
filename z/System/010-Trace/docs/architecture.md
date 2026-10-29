# Trace architecture

[Subsystem](readme.md) | [Object index](reference/readme.md)

## Configuration and execution

Framework procedures build run-owned logical definitions in `z.Trace`, `z.TraceEvent`, `z.TraceEventColumn`, `z.TraceFilter` and `z.TraceTrigger`. Create registers a Building run; Start enables a definition and Stop disables it. These operations allocate no native trace. Event, column, filter and callback configuration remains possible after Start while the run is Building. Start requires the owning session. Stop and Close accept explicit logical selectors across owners, including during collection; neither selector means the current context run only.

Collect freezes all enabled definitions and captures their event-column union, including filter inputs, through overlapping native rowset generations. One receiving connection drains them sequentially. Only an identical single SPID predicate shared by every enabled definition can be pushed down. Independent logical filters run locally: AND across column groups; ordered left-fold AND/OR within a column, ignoring its first operator. Missing/NULL fields do not match. Each generated route also checks that its logical definition still exists and is enabled, allowing another session to Stop or Close it. When none remain enabled, the receiver finishes.

Each generation has a scheduled native expiry. The receiver keeps four future generations ahead, calls sp_trace_getdata directly with records = 0 into an identity-ordered temporary buffer, then decodes the completed buffer through a local static read-only cursor. Other generations capture while that buffer is processed. Expiry and EOF timing are soft; the nominal two-second spacing is not a strict processing deadline. EventSequence is captured internally, and an exact temporary sequence set suppresses overlapping copies before logical routing. It is exposed only when selected. Seen identities are pruned after the remaining matching native generations were allocated later than their processing time, with a grace interval.

Default commits occur after two seconds or 300 newly processed physical events, and any remaining batch commits at the end of the buffer. Control frames, overlapping copies and fan-out deliveries do not inflate the event count. All deliveries and callbacks for one physical event share its transaction. Callback failure rolls back the current batch; prior commits remain. The decoder survives commits. No destination transaction is held open during the next native capture. Native consumption cannot be rolled back.

Closing a collecting run removes all owned native generations and run-owned definitions, including disabled definitions. Destination data remains. Buffering and decoding run sequentially in the same collection procedure; no API cursor, helper connection, job or Broker worker is used.

## Ownership and cleanup

`z.TraceCollector` binds a run UUID to session ID, login generation and Building/Collecting state. The reserved context key is `Schema z.TraceCollector.UUID`. `z.TraceCollectorTrace` records each native generation by (CollectorUUID, TraceID, NativeStopTime), including its native start time. Different sessions can use identical logical names and collect independently.

Cleanup preserves Building configuration while the original session/login exists, including idle gaps. Collecting runs are preserved while the owner has any active request, including unrelated or blocked work. Otherwise a separate privileged connection can clean the run. Reused native IDs with mismatched generation tags are preserved for review. Cancellation between native allocation and registration can leave an unregistered resource; cleanup never guesses ownership.

Use one dedicated, non-MARS connection and database per run. The registry/coordination lock is database-scoped but session context is connection-scoped. Do not mark the reserved UUID key read-only.

## Installation and inspection

System supplies sequence, naming and partition foundations. Trace installs before [Monitoring](../../020-Monitoring/docs/readme.md), which owns diagnostic presets, destination tables and snapshot callbacks. Installation refreshes catalog views without entering collection.

Internal tables have separate guarded baseline definitions without foreign keys. The physical-generation mapping baseline upgrades the original CollectorUUID-only primary key when that baseline is eligible to run. Other table shapes are not reconciled. No subsystem version increase or new migration is supplied. TraceID selectors identify logical definitions; collection does not accept TraceName/TraceID selectors.

`z.v_Trace` and `z.v_TraceOwned` expose logical definitions and their native generations. During collection a logical definition can appear once per mapped native generation. Before collection its native identity is NULL. The generated `z.v_TraceDefinition` remains a native trace/event matrix, and `z.v_TraceMetaData` remains an event-column capability catalog.

The receiver replenishes capture before decoding a completed buffer, preferring a running generation that overlaps the previous coverage boundary. Short native expiries supply the periodic processing cadence without record-count polling or a second receiver.

## Transport limits

The generated receive loop adds no custom completeness or defensive exceptions. Native SQL and callback errors still propagate. Native buffers can overflow, and processing delays can exhaust the available overlap; successful return and zero reported drops do not certify complete reception. Callbacks query current state when the buffer is processed, not at the original event time. Processing/capture duration remains soft. Production is T-SQL-only, without SQLCLR, loopback or file-backed Trace.

Local character filters use the database collation; their text-comparison behavior follows SQL expressions in that database.
