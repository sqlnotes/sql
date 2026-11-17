# Semaphores and trigger flags

[Object index](readme.md) · [Declarations and sources](procedures.md)

## Semaphores

Product routines coordinate through `z.usp_AcquireSemaphore` and `z.usp_ReleaseSemaphore`. Native application-lock operations are encapsulated by these helpers. Acquisition takes `@SemaphoreName`, total capacity (default 1), owner (default Transaction), `@LockTimeout` in milliseconds (default -1, infinite). Success returns a positive slot number; a nonpositive result is not acquisition. A zero timeout makes one nonblocking scan; positive timeouts bound the wait for a slot.

The implementation validates inputs and transaction ownership, obtains an intent-exclusive marker on the name and an exclusive slot lock named `<slot>-<SemaphoreName>`, and polls when capacity is occupied. Database- and owner-specific hashed session-context keys record the slot without depending on name length. Transaction ownership requires an open transaction; commit or rollback releases its locks. Session ownership requires explicit release or session termination. All participants must agree on name, owner and capacity.

If the same database, session and lock owner already hold the semaphore, acquisition returns the existing slot immediately. It acquires no additional native locks and increments no reference counts. Only the outer operation that acquired the permit releases it; nested callers reusing that permit must leave it held. Transaction-owned permits are released when the outer transaction ends. Release takes only `@SemaphoreName` and checks both owner-specific context keys and native locks. NULL, empty, missing and already-released semaphores are harmless no-ops returning 0. Stale context is cleared. If both owner scopes hold the name, release cleans up both scopes. It also releases a held marker left without slot context by an interrupted acquisition. A catchable cleanup failure returns a negative status without throwing and the other owner scope is still attempted. Release preserves the caller's transaction. These routines start no transaction and require ordinary application-lock access.

Timeout and catchable failure paths clean up partial acquisitions. Client attention is not reliably catchable in T-SQL: interrupted Session work can still require explicit cleanup or closing the physical connection. The retained raw main/slot resource naming can collide when arbitrary semaphore names imitate another semaphore's slot name. Use consistent application-owned names and review cancellation behavior for the intended workload; these changes do not establish a full lifecycle or fairness guarantee.

Drain active semaphore users before updating these helper definitions. The owner-specific context format replaces the legacy context key; existing holders must finish using their original release implementation or close their physical connections before the update.

Release no longer accepts `@LockOwner`; update named and second-positional owner arguments together with the helper definition. Acquisition still accepts `@LockOwner`. Within the same session and database, acquisition rejects holding the same name under both owners simultaneously.

The first parameter was formerly named `@Resource`. Update named-parameter calls to `@SemaphoreName`; positional calls continue to work. The underlying SQL Server application-lock procedures still use their own `@Resource` parameter.

## Trigger flags

`z.usp_SkipTrigger` stores `SkipTriggerFlag` from comma-separated parent/trigger names, or literal `all`. Calling without arguments stores null to clear it.

`z.fn_ShouldSkipTrigger` returns bit for a trigger ID. A trigger must explicitly call it and return early; the procedure does not disable catalog triggers. This is not a permission boundary. Context persists on the same connection and should be reset after use. Catalog visibility governs selected triggers.
