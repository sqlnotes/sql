# Trace architecture

[Subsystem](readme.md) | [Object index](reference/readme.md)

## Configuration and execution

Framework procedures build run-owned logical definitions in `z.Trace`, `z.TraceEvent`, `z.TraceEventColumn`, `z.TraceFilter` and `z.TraceTrigger`. Create registers a Building run; Start enables a definition and Stop disables it. These operations allocate no native trace. Event, column, filter and callback configuration remains possible after Start while the run is Building.

Collect freezes all enabled definitions, creates one physical rowset trace and enables their event-column union, including filter inputs. Only an identical single SPID predicate shared by every enabled definition can be pushed down. Independent logical filters run locally: AND across column groups, ordered left-fold AND/OR within each column, with the first operator ignored. Missing fields and SQL UNKNOWN do not match.

A named static API cursor opens directly over the native reader and consumes its rows in order. Collection reuses that cursor with CLOSE/OPEN between bounded reads, then releases it with sp_cursorclose on completion or error. There is no explicit temporary receiving buffer; SQL Server still materializes the static cursor snapshot internally. A following frame header or cursor EOF completes the preceding event; control records are handled separately. Each physical event is decoded once and routed to every matching definition. Each delivery receives its own TraceSequence. An all-event callback overrides an event-specific registration; callbacks receive named TraceSequence, logical TraceID and EventName arguments after the destination insert.

Default commits occur after two seconds or 300 physical real events. Control records and fan-out deliveries do not inflate the event count. All deliveries and callbacks for a physical event share its batch transaction. Callback failure rolls back the current batch; prior commits remain. Blocking reads and slow callbacks can extend the time budget. Native consumption cannot be rolled back.

Closing a collecting run removes its physical trace and all run-owned definitions, including disabled definitions. Destination data remains. Raw saving and parsing are not separate execution stages.

## Ownership and cleanup

`z.TraceCollector` binds a run UUID to session ID, login generation and Building/Collecting state. The reserved context key is `Schema z.TraceCollector.UUID`. `z.TraceCollectorTrace` records one native ID with expiry/start-time generation tags. Different sessions can use identical logical names and collect independently.

Cleanup preserves Building configuration while the original session/login exists, including idle gaps. Collecting runs are preserved while the owner has any active request, including unrelated or blocked work. Otherwise a separate privileged connection can clean the run. Reused native IDs with mismatched generation tags are preserved for review. Cancellation between native allocation and registration can leave an unregistered resource; cleanup never guesses ownership.

Use one dedicated, non-MARS connection and database per run. The registry/coordination lock is database-scoped but session context is connection-scoped. Do not mark the reserved UUID key read-only.

## Installation and inspection

System supplies sequence, naming and partition foundations. Trace installs before [Monitoring](../../020-Monitoring/docs/readme.md), which owns diagnostic presets, destination tables and snapshot callbacks. Installation refreshes catalog views without entering collection.

Internal tables have separate guarded baseline definitions without foreign keys. This initial redesign has no migration or version bump. Existing tables are not reconciled: install fresh or explicitly recreate the development schema. TraceID selectors now identify logical definitions. Collect no longer accepts TraceName/TraceID selectors; positional callers must adopt the new signature.

`z.v_Trace` and `z.v_TraceOwned` describe logical definitions and their shared NativeTraceID. The generated `z.v_TraceDefinition` remains a native trace/event matrix, and `z.v_TraceMetaData` remains an event-column capability catalog. Their native IDs are distinct from logical IDs.

Idle control-only reads flush the current transaction and back off through 10, 20, 40, 80, 160, 320, 640 and 1,000 milliseconds. Further idle waits stay at one second. A real physical event resets the backoff, and collection reads again immediately after processing it. Polling delays affect detection latency and the soft capture-duration bound; they do not repair native bounded-read event loss.

## Transport limits

The bounded one-frame `sp_trace_getdata` backend can lose unread events between calls, including with zero reported native drops. Collection does not poll native counters or raise its own exceptions for reported drops, missing events or unavailable diagnostic counters. Native SQL/API and callback errors still propagate; successful completion does not establish complete reception. Consolidation does not establish losslessness, a performance winner or a strict callback deadline. Native trace removal does not guarantee an immediate SQL/API error; if the reader returns without an error, collection can continue idle until the duration limit or cancellation. Production remains T-SQL-only without SQLCLR or loopback dependencies.

Local character filters use the database collation; their text-comparison behavior follows SQL expressions in that database.
