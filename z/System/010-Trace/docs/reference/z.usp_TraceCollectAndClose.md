# z.usp_TraceCollectAndClose

[Trace](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_TraceCollectAndClose.sql)

## Purpose and behavior

Collect every enabled logical definition in the current session's run. Freeze configuration and allocate/start one physical rowset trace containing the required event-column union, including filter inputs. No native trace exists during logical Create/Start. Different sessions collect independently.

Prepare missing receiving tables and required nullable output columns. Decode each physical event once, apply each logical definition's independent typed predicates, and route every match to its configured destination. Give each logical delivery a separate TraceSequence. An all-event callback overrides its event-specific registration and receives named TraceSequence, logical TraceID and EventName parameters after the insert.

On completion close the one owned physical trace and remove the entire run's configuration, including disabled definitions. Destination tables/data remain. On failure roll back the current collection batch, attempt generation-safe run cleanup, and rethrow the original error. Prior committed batches survive.

## Parameters and defaults

```text
@MaxDurationInSec int = 2147483647,
@TransactionDurationInSec int = 2,
@MaxEventsPerTransaction int = 300
```

TraceName/TraceID selectors have been removed. Update named and positional callers to this signature. MaxDurationInSec must be nonnegative; transaction duration and event cap must be positive. Reject ambient transactions. Bound the long default duration during development.

## Transactions and filtering

Commit after the time budget or physical-event cap, whichever is reached first. Controls and fan-out deliveries do not count as additional physical events. Every matching delivery and callback for a physical event stays in its batch transaction. Callback failure can roll back earlier events in that same batch. Blocking reads and callbacks can exceed the time budget; it is not a strict deadline.

When a read contains no real physical events, commit any current batch before waiting. Idle waits increase through 10, 20, 40, 80, 160, 320, 640 and 1,000 milliseconds, then remain capped at one second. Control frames do not reset the backoff. A real event resets it to 10 milliseconds, and the next read begins immediately after processing, even if local filters rejected that event. At the cap, polling adds up to the scheduled one-second wait before detecting new traffic; server scheduling, reads and callbacks add their own time. The capture-duration limit is also soft and may be exceeded by the final idle wait and cleanup.

Filters are ANDed across column groups. Within a column, fold predicates in FilterOrdinal order using their stored AND/OR operator, ignoring the first operator. Missing/NULL fields yield SQL UNKNOWN and do not match. Only a common, single SPID predicate proven safe for all enabled definitions is eligible for native pushdown.

## Permissions and limits

Events are written to receiving tables. API cursor calls can emit empty result-set metadata; client code must execute collection to completion and consume all results and errors. Requires registered session/login/UUID ownership, native trace privileges, catalog access, destination DDL/DML and callback privileges. Configuration freezes in Collecting. Receiving tables and configured callbacks are validated/prepared before reception.

A named static API cursor opens directly over sp_trace_getdata with a native count of one frame. SQL FETCH reads ColumnID, Length and Data. Each read uses a fresh cursor; sp_cursorclose releases its handle after decoding, with final/error cleanup protecting outstanding handles. Creating a fresh cursor avoids SET-option errors on cursor reopen and adds cursor setup work per read. This removes the explicit temporary buffer, INSERT EXEC and TRUNCATE; SQL Server still materializes each static snapshot internally. The bounded rowset backend can lose unread events between calls, including with zero native drops. Collection does not poll native counters or compare received events against native counts, and does not raise its own exceptions for reported drops, missing events or unavailable diagnostic counters. Genuine SQL/API and callback errors still propagate. Successful return, logical merging and zero reported drops are not a losslessness guarantee. Native trace removal does not guarantee an immediate SQL/API error; if the reader returns without an error, collection can continue idle until the duration limit or cancellation. Raw saving and parsing are not separate stages. Production has no SQLCLR or loopback dependency.

See [architecture](../architecture.md) and [cleanup](z.usp_TraceCleanupCollectors.md).
