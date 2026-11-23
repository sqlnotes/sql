# Semaphores and trigger flags

[Object index](readme.md) · [Declarations and sources](procedures.md)

## Semaphores

Use `z.usp_AcquireSemaphore` to reserve one of `@TotalCount` slots (default 1). All callers must agree on the name, capacity and owner. A positive return value identifies the acquired slot. A negative value indicates failure. Set `@LockTimeout` in milliseconds, use 0 for one nonblocking scan, or use the default -1 to wait indefinitely.

The default Transaction owner requires an open transaction. Commit or rollback releases its locks. A Session permit lasts until explicit release or physical disconnection. Reacquiring the same permit from the same session and owner returns the existing slot. Only the outer caller releases it. An acquisition under the other owner is rejected while that permit is held.

Acquire uses an exclusive application lock on `<slot>-<SemaphoreName>`. A session-context key per database and semaphore name stores the owner and candidate slot. The native lock determines whether the slot is held. A transaction ending releases its native lock. The context entry can outlive the transaction, and the next acquisition of the same name reuses that key. Explicit release or closing the connection clears the entry.

`z.usp_ReleaseSemaphore` takes `@SemaphoreName` and optional `@SuppressException`, default `0`. It uses the recorded owner, releases the recorded slot, and clears the context entry on successful cleanup. NULL, blank, missing and already-released names return 0. Native negative return codes are passed back. Caught exceptions are rethrown by default. With `@SuppressException = 1`, the helper prints the exception and returns `-999`. Release preserves the caller's transaction. If cancellation leaves a Session lock held, release it on the same physical connection or close that connection.

**Upgrading older callers.** Let holders using an older context format release their permits or close their connections before replacing the helpers. Current release looks up the current per-name key only. Use `@SemaphoreName` for named calls and remove the former release `@LockOwner` argument.

## Trigger flags

`z.usp_SkipTrigger` stores `SkipTriggerFlag` from comma-separated parent/trigger names, or literal `all`. Calling without arguments stores null to clear it.

`z.fn_ShouldSkipTrigger` returns bit for a trigger ID. A trigger must explicitly call it and return early; the procedure does not disable catalog triggers. This is not a permission boundary. Context persists on the same connection and should be reset after use. Catalog visibility governs selected triggers.
