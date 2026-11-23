# Semaphores and trigger flags

[Object index](readme.md) · [Declarations and sources](procedures.md)

These helpers let cooperating procedures coordinate work within a database. Semaphores limit how many sessions may enter an operation; trigger flags let a connection ask specially written triggers to skip their work. Both rely on callers using the same convention.

## Semaphores

Use `z.usp_AcquireSemaphore` to reserve one of `@TotalCount` slots (default 1). All callers must agree on the name, capacity and owner. A positive return value identifies the acquired slot. A negative value indicates failure. Set `@LockTimeout` in milliseconds, use 0 for one nonblocking scan, or use the default -1 to wait indefinitely.

The default Transaction owner requires an open transaction. Commit or rollback releases its locks. A Session permit lasts until explicit release or physical disconnection. Reacquiring the same permit from the same session and owner returns the existing slot. Only the outer caller releases it. An acquisition under the other owner is rejected while that permit is held.

Semaphores coordinate callers in the same database. Use a stable name for the protected operation and check the acquisition result before entering it. They do not keep a record of completed work, so releasing a semaphore lets another caller perform that work again.

`z.usp_ReleaseSemaphore` takes `@SemaphoreName` and optional `@SuppressException`, default `0`. It uses the recorded owner, releases the recorded slot, and clears the context entry on successful cleanup. NULL, blank, missing and already-released names return 0. Native negative return codes are passed back. Caught exceptions are rethrown by default. With `@SuppressException = 1`, the helper prints the exception and returns `-999`. Release preserves the caller's transaction. If cancellation leaves a Session lock held, release it on the same physical connection or close that connection.

For lock diagnostics, each slot uses application-lock resource `<slot>-<SemaphoreName>`. Ownership is tracked per database and name in session context, while the native lock determines whether the slot is held. A transaction can end before that tracking entry is cleared. If a connection reaches session-context memory error 15665 after using many distinct names, releasing permits alone may not recover the memory; closing the physical connection clears its context. The [helper sources](procedures.md#zusp_acquiresemaphore) contain the tracking details.

**Upgrading older callers.** Let holders using an older context format release their permits or close their connections before replacing the helpers. Current release looks up the current per-name key only. Use `@SemaphoreName` for named calls and remove the former release `@LockOwner` argument.

## Trigger flags

Use `z.usp_SkipTrigger` to request that selected triggers skip work on this connection. Supply comma-separated parent object names or trigger names, or the literal `all`. Call it without arguments afterward to clear the request.

A trigger honors the request only if it calls `z.fn_ShouldSkipTrigger` with its trigger ID and returns early when the result is 1. Other triggers continue normally; no trigger is disabled in SQL Server's catalog. This convention does not grant permissions or enforce a security boundary. Metadata visibility determines which named triggers can be selected.
