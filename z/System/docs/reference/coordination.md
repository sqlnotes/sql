# Semaphores and trigger flags

[Object index](readme.md) · [Declarations and sources](procedures.md)

## Semaphores

Use `z.usp_AcquireSemaphore` to reserve one of `@TotalCount` slots (default 1). All callers must agree on the name, capacity and owner. A positive return value identifies the acquired slot. A negative value indicates failure. Set `@LockTimeout` in milliseconds, use 0 for one nonblocking scan, or use the default -1 to wait indefinitely.

The default Transaction owner requires an open transaction. Commit or rollback releases its locks. A Session permit lasts until explicit release or physical disconnection. Reacquiring the same permit from the same session and owner returns the existing slot. Only the outer caller releases it. An acquisition under the other owner is rejected while that permit is held.

Acquire uses an intent-exclusive lock on the semaphore name and an exclusive lock on `<slot>-<SemaphoreName>`. Choose names that cannot collide with another semaphore's slot name. For workloads that use many distinct names, use a connection with Multiple Active Result Sets (MARS) disabled. That connection reuses slot records. MARS keeps a separate session-context key per name and owner so overlapping requests can release their own permits. A long-lived MARS connection using many distinct names can reach SQL Server's 1 MB session-context limit, even after releasing permits.

`z.usp_ReleaseSemaphore` takes only `@SemaphoreName`. It checks both owners, releases any slots and markers it finds, and preserves the caller's transaction. NULL, empty, missing and already-released names return 0. A catchable cleanup failure returns a negative status after both owners have been attempted. Client cancellation can leave Session locks behind. Finish cleanup on the same physical connection or close it.

**Upgrading older callers.** The helpers recognize the previous database- and owner-specific per-name keys. Before upgrading from the earlier single-key format, let existing holders release their permits or close those physical connections. Change named `@Resource` arguments to `@SemaphoreName` and remove the former second `@LockOwner` argument from release calls.

## Trigger flags

`z.usp_SkipTrigger` stores `SkipTriggerFlag` from comma-separated parent/trigger names, or literal `all`. Calling without arguments stores null to clear it.

`z.fn_ShouldSkipTrigger` returns bit for a trigger ID. A trigger must explicitly call it and return early; the procedure does not disable catalog triggers. This is not a permission boundary. Context persists on the same connection and should be reset after use. Catalog visibility governs selected triggers.
