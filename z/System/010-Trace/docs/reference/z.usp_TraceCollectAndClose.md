# z.usp_TraceCollectAndClose

[Trace](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_TraceCollectAndClose.sql)

Collects events from this connection's running traces into their receiving tables, then closes the selected traces. Use it after configuring and starting capture. Missing receiving tables are created with the selected output columns; the tables and recorded data remain after collection ends.

Use one dedicated connection without Multiple Active Result Sets (MARS), and run outside an existing transaction. Collection is best effort: a successful return does not guarantee that every captured event arrived.

```text
@MaxDurationInSec int = 2147483647,
@TransactionDurationInSec int = 5,
@MaxEventsPerTransaction int = null,
@TraceName nvarchar(128) = null,
@TraceID int = null
```

| Parameter | Meaning |
| --- | --- |
| `@MaxDurationInSec` | How long to collect before closing the traces. The default is effectively continuous collection; zero closes selected traces without reading events. Must be nonnegative. |
| `@TransactionDurationInSec` | Approximate window between commits of received events; defaults to 5 seconds and must be positive. |
| `@MaxEventsPerTransaction` | Optional positive event limit that can commit a batch sooner. NULL leaves batching time-based. |
| `@TraceName`, `@TraceID` | Optional selectors for this connection's traces. Omit both to collect all its running traces. Use named arguments; the first three parameter positions are retained. |

Each recorded event receives a `TraceSequence`. Its insert and callback commit or roll back together. Callbacks accept named `@TraceSequence`, `@TraceID` and `@EventName`; an `all` callback takes precedence over event-specific callbacks. They must not commit or roll back the collector's transaction.

The duration and commit windows are approximate. Native reads, callbacks, waiting and scheduling can delay them, and locks remain held until commit. Pending rows are committed on normal completion. Existing destination event columns are not retyped or fully validated beyond the required base columns.

If a selected trace is stopped or closed elsewhere, collection normally continues for the other traces. An actual collection failure rolls back the current batch, reports trace/operation context, attempts cleanup and rethrows the original error. Earlier commits remain. Events already consumed from SQL Trace cannot be read back by rolling back the database transaction. Cancellation may require [abandoned cleanup](z.usp_TraceCleanup.md) after disconnect.

The procedure stores events rather than returning them as a defined result set. The caller needs SQL Trace and metadata access, permission to create/write receiving tables, and permission to execute callbacks. See [architecture](../architecture.md) for delivery and transaction limits.
