# Semaphores and trigger flags

[Object index](readme.md) · [Declarations and sources](procedures.md)

These helpers let cooperating procedures coordinate work within a database. Semaphores limit how many sessions may enter an operation; trigger flags let a connection ask specially written triggers to skip their work. Both rely on callers using the same convention.

## Semaphores

Use `z.usp_AcquireSemaphore` to reserve one of `@TotalCount` slots (default 1). A positive return value is the acquired slot. A negative value indicates failure. Set `@LockTimeout` in milliseconds, use 0 for one nonblocking attempt across the slot range, or use the default -1 to wait indefinitely.

Connections share the configured slot limit. Session and Transaction ownership on the same connection can share one numbered slot. A Transaction hold requires an open transaction and ends on commit or rollback. A Session hold ends on explicit release or physical disconnection. The slot becomes available to another connection only after both holds end.

Acquire holds a Shared application lock on `z.Semaphore:<SemaphoreName>` in the requested scope once it grants a slot. Acquire checks the requested owner first. If that owner already holds the permit, it returns the existing slot without adding a lock reference. If only the other owner on the connection holds the permit, acquire adds an Exclusive hold for the requested owner on the same slot and a Shared marker for that owner on the semaphore name. If the offered capacity excludes the held slot, acquire throws error 50000. Release the original slot before reacquiring at the smaller capacity. Only the outer caller releases a reacquired permit.

`z.usp_ReleaseSemaphore` defaults `@Slot` to 1 and `@LockOwner` to `'Transaction'`. Pass the acquired slot for a multi-slot semaphore and use `@LockOwner = 'Session'` to release a Session permit. Release frees the exact slot and its marker for the requested owner. If both scopes hold the same slot, the other scope keeps it reserved after release. If the requested owner has no hold on the specified slot, release returns success without changing either scope. Native negative statuses are returned to the caller. With `@SuppressException = 1`, release prints caught exceptions and returns `-999`.

Semaphores coordinate callers in the same database. Use a stable name and agreed capacity for the protected operation. Each slot uses the native application-lock resource `<slot>-<SemaphoreName>`. Call release on the acquiring connection. If an interruption occurs before the acquired slot reaches the caller, closing the physical connection releases any Session-owned slot.

**Upgrade.** Let active holders in both ownership scopes release or finish before replacing the helpers. Update Session callers to pass `@LockOwner = 'Session'` and regenerate existing [AsyncChannel activators](../../050-AsyncChannel/docs/usage.md) before resuming channel processing.

## Trigger flags

Use `z.usp_SkipTrigger` to request that selected triggers skip work on this connection. Supply comma-separated parent object names or trigger names, or the literal `all`. Call it without arguments afterward to clear the request.

A trigger honors the request only if it calls `z.fn_ShouldSkipTrigger` with its trigger ID and returns early when the result is 1. Other triggers continue normally; no trigger is disabled in SQL Server's catalog. This convention does not grant permissions or enforce a security boundary. Metadata visibility determines which named triggers can be selected.
