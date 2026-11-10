# z.usp_TraceCollectAndClose

[Trace](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_TraceCollectAndClose.sql)

Collect running physical traces created by this session/login, optionally selected by name or native ID. Prepare destination tables and only selected output columns, poll each trace with sp_trace_getdata records = 1, and process every decoded event in buffer order. Traces keep running between reads with no scheduled stop time.

```text
@MaxDurationInSec int = 2147483647,
@TransactionDurationInSec int = 5,
@MaxEventsPerTransaction int = null,
@TraceName nvarchar(128) = null,
@TraceID int = null
```

The first three parameter positions are retained. Use named selectors. Duration must be nonnegative; transaction duration and any supplied event limit must be positive. NULL disables the event limit. Ambient transactions are rejected. The total duration is soft and does not set native stoptime; zero selects and closes without polling.

Each complete event resets its fields, restores selected EventClass from its header, and receives a TraceSequence. Its insert and callback share one transaction. Callbacks accept @TraceSequence, @TraceID and @EventName; all overrides event-specific registration. They must not change transactions. Transactions span buffers, native reads and idle waits. By default, commit pending work after 5 seconds; @TransactionDurationInSec adjusts this window and an optional @MaxEventsPerTransaction can commit earlier. The deadline is checked before each native read, after each event and before an idle wait. Idle polling requests a 4 ms wait. Native reads, callbacks and scheduling can delay the deadline; locks remain held until commit. Normal collection completion flushes pending work. Datetimes decode from numeric parts. Existing destination columns are not retyped or fully validated beyond the required base columns.

A selected trace stopped or closed elsewhere normally leaves polling, while other selected traces continue. If a concurrent native read error leaves the pending transaction uncommittable, it is rolled back and the original error is preserved. Normal completion closes the original selected trace IDs and creator session/login and removes their configuration, retaining output tables/data. Failures roll back the current batch, print trace/operation context, attempt cleanup and rethrow the original error. Native consumption is not transactional; prior commits survive. Cancellation may require abandoned cleanup after disconnect.

Use one dedicated non-MARS connection. SQL Trace, metadata, destination DDL/DML and callback privileges are required. Bounded reads have known reception loss; successful return is not a completeness guarantee. See [architecture](../architecture.md) and [cleanup](z.usp_TraceCleanup.md).
