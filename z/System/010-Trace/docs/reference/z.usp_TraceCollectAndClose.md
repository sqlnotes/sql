# z.usp_TraceCollectAndClose

[Trace](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_TraceCollectAndClose.sql)

## Purpose and behavior

Collect every enabled logical definition in the current session's run. Freeze configuration and start overlapping physical rowset generations containing the required event-column union, including filter inputs and internal EventSequence. One connection receives and processes all generations. Logical Create/Start allocate no native trace; other sessions collect independently.

Prepare missing receiving tables and required nullable output columns. Decode each physical event once, apply each logical definition's independent typed predicates, and route every match to its configured destination. Give each logical delivery a separate TraceSequence. An all-event callback overrides its event-specific registration and receives named TraceSequence, logical TraceID and EventName parameters after the insert.

On completion close all owned native generations and remove the run's configuration, including disabled definitions. Destination data remains. On failure roll back the current collection batch, attempt generation-safe cleanup, and rethrow the original error. Prior committed batches survive.

## Parameters and defaults

```text
@MaxDurationInSec int = 2147483647,
@TransactionDurationInSec int = 2,
@MaxEventsPerTransaction int = 300
```

TraceName/TraceID selectors have been removed. Update named and positional callers to this signature. MaxDurationInSec must be nonnegative; transaction duration and event cap must be positive. Reject ambient transactions. Bound the long default duration during development.

## Transactions and filtering

Commit after the time budget or physical-event cap, whichever is reached first, and commit the remainder at the end of a processed buffer. Controls, overlapping copies and fan-out deliveries do not add physical events to this count. Every matching delivery and callback for a physical event stays in one transaction. Callback failure can roll back earlier events in that batch. Blocking reads and callbacks can exceed the time budget.

The receiver uses direct INSERT EXEC sp_trace_getdata with records = 0 into a temporary table. Native expiry ends that generation's stream; a local static read-only cursor then processes its rows in insertion order while replacement generations continue capturing. Four future generations are maintained with nominal two-second expiry spacing. Native expiry/EOF scheduling and buffer processing can exceed that spacing; there is no strict callback-latency guarantee.

Filters are ANDed across column groups. Within a column, fold predicates in FilterOrdinal order using their stored AND/OR operator, ignoring the first operator. Missing/NULL fields yield SQL UNKNOWN and do not match. Only a common, single SPID predicate proven safe for all enabled definitions is eligible for native pushdown.

## Permissions and limits

Events are written to receiving tables during collection. Client code must execute collection to completion and consume all results and errors. Requires registered session/login/UUID ownership, native trace privileges, catalog access, destination DDL/DML and callback privileges. Configuration freezes in Collecting. Receiving tables and configured callbacks are validated/prepared before reception.

An exact temporary EventSequence set prevents overlapping copies from producing duplicate logical deliveries. Internal EventSequence capture does not change output-column masking. Seen identities are retained while older matching generations can still contain copies, then pruned conservatively. The generated loop adds no custom completeness exceptions. Genuine SQL and callback errors still propagate. Native buffering and available overlap are finite: overflow or processing delays can still affect reception. Successful return and zero reported drops do not prove completeness. Buffering and decoding occur sequentially in one receiver, without an API cursor, helper connection, SQLCLR, loopback or file-backed Trace.

See [architecture](../architecture.md) and [cleanup](z.usp_TraceCleanupCollectors.md).
