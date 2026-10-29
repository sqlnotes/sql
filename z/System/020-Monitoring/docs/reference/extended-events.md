# Error and long-running query Extended Events

[Monitoring](../readme.md) | [Object index](readme.md)

These server-scoped sessions capture all databases. Error capture has no QRTZ
exclusion. They are separate from the SQL Trace framework and system_health.
Installing Monitoring defines procedures and tables; it does not create or start
these server sessions. The error/long-query collectors call their matching creator
to ensure the session exists and is running before reading its buffer.

## z.usp_CreateErrorEventSession

[Source](../../modules/1070%20Procedures/z.usp_CreateErrorEventSession.sql)

Creates `SchemaZ Error Events` only if absent and starts it if stopped. Captures
sqlserver.error_reported with severity > 10. Actions retain event sequence,
collection time, application, host, context information, database, server instance,
session server principal and SQL text. An existing definition is retained without
reconciling its events, predicates or settings. No parameters or result set.

## z.usp_CreateLongRunningQueryEventSession

[Source](../../modules/1070%20Procedures/z.usp_CreateLongRunningQueryEventSession.sql)

Creates `SchemaZ Long Running Query Events` only if absent and starts it if
stopped. Captures rpc_completed, sql_batch_completed, sp_statement_completed and
sql_statement_completed with duration >= 1300000 microseconds (1.3 seconds).
Actions retain event sequence, collection time, host, context information,
database, server principal, session ID, SQL text and application. There is no
database predicate. Existing definitions are retained. No parameters or result set.

Both sessions explicitly set the ring_buffer target MAX_MEMORY to 4096 KB,
separately from session MAX_MEMORY = 4096 KB. Other options are
ALLOW_SINGLE_EVENT_LOSS, MAX_DISPATCH_LATENCY = 30 SECONDS, MAX_EVENT_SIZE = 0 KB,
MEMORY_PARTITION_MODE = NONE, TRACK_CAUSALITY = OFF and STARTUP_STATE = ON.
The procedures also start stopped sessions immediately when invoked. If a
concurrent caller creates or starts the same session first, the procedure
rechecks the resulting state before accepting that race. Errors propagate when
the configured/running state was not reached, or if the caught failure changed
the caller transaction count or left it uncommittable.

Creation/start requires server event-session permissions: ALTER ANY EVENT SESSION
on SQL Server 2019, or the appropriate granular create/enable permissions on
SQL Server 2022 and later. The procedures grant no privileges.

## z.usp_CollectErrorEvents

[Source](../../modules/1070%20Procedures/z.usp_CollectErrorEvents.sql)

Reads the running `SchemaZ Error Events` ring-buffer target and appends extracted
rows to z.ErrorEvent. First calls z.usp_CreateErrorEventSession, which creates
the session if absent and starts it if stopped. An absent ring-buffer target
supplies no events. A newly started session may have no dispatched events yet. Existing stored events remain;
collection has no retention deletion or alert delivery. No parameters or result set.

## z.usp_CollectLongRunningQueryEvents

[Source](../../modules/1070%20Procedures/z.usp_CollectLongRunningQueryEvents.sql)

Reads the running `SchemaZ Long Running Query Events` ring-buffer target and
appends extracted rows to z.LongRunningQueryEvent. Same lifecycle and retention
behavior as z.usp_CollectErrorEvents. No parameters or result set.

Each collector uses READ COMMITTED and begins/commits a transaction around its
insert, taking an exclusive transaction-owned application lock with a 10-second
timeout. Existing caller transactions are allowed; a successful call balances
its own BEGIN/COMMIT and leaves the outer transaction open. Its application lock
remains until that outer transaction ends. On failure the catch rolls back the
entire active transaction, including caller work, and rethrows. Repeated payloads
are deduplicated within the read and against persisted event keys. Concurrent
calls to the same collector serialize in the destination database; collectors
do not coordinate direct writes by other code.

Collectors require destination insert/select access, server-session creation/start
permissions when needed, and server DMV visibility
(VIEW SERVER STATE on SQL Server 2019; VIEW SERVER PERFORMANCE STATE on SQL Server
2022 and later). They do not elevate permissions or schedule themselves.

## z.fn_ExtractErrorEvent

[Source](../../modules/1010%20Functions/z.fn_ExtractErrorEvent.sql)

Pure XML table-valued decoder taking `@TargetData xml` with a RingBufferTarget
root. Returns error metadata, message, SQL text, principal, instance, database,
context, host and application, plus event identity, UTC time and original XML.

## z.fn_ExtractLongRunningQueryEvent

[Source](../../modules/1010%20Functions/z.fn_ExtractLongRunningQueryEvent.sql)

Pure XML table-valued decoder taking `@TargetData xml`. Returns completion-event
identity, UTC time and original XML, session ID, CPU, duration in milliseconds,
reads, writes, row count, connection reset option, object name, SQL text,
principal, database, context, host and application. SQL text prefers statement,
then batch_text, then the sql_text action. Optional absent payloads remain null.

## z.ErrorEvent

[Source](../../baseline/2020%20Tables/z.ErrorEvent.sql)

Typed error-event storage plus EventBody XML. EventDateUTC stores the UTC XE
timestamp as datetime, matching the shared PS_SchemaZPartitionGenericDateTime
scheme. The primary key is (EventDateUTC, EventName, EventSequence).
EventDateUTC has SQL datetime precision; the original XML retains the full event
timestamp. No encoded bigint time key or automatic retention is used.

## z.LongRunningQueryEvent

[Source](../../baseline/2020%20Tables/z.LongRunningQueryEvent.sql)

Typed completion-event storage plus EventBody XML, with the same UTC datetime and
partition-key conventions. DurationInMS is duration converted from microseconds;
CPU retains the source event's native units. Repeated events can describe a batch
and its statements separately; the four completion classes are not unique queries.

Both guarded baselines only create absent tables. Existing installations above
Monitoring version 0.0.0 skip baselines; prepare missing tables explicitly before
running collectors. No migration or subsystem version change is supplied.

## Reception limits

The ring buffer is volatile and bounded: old events can be overwritten, and
stopping a session discards its buffer. ALLOW_SINGLE_EVENT_LOSS permits loss.
Reading target_data does not consume it; repeat collection skips already stored
event keys. XML conversion has a 4 MB ceiling and can omit buffered events even
with a 4 MB target. A successful poll cannot certify complete capture.

See Microsoft's [target documentation](https://learn.microsoft.com/en-us/sql/relational-databases/extended-events/targets-for-extended-events-in-sql-server)
and [session DDL reference](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-event-session-transact-sql).
