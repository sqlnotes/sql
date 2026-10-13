# Semaphores and trigger flags

[Object index](readme.md) · [Declarations and sources](procedures.md)

## Semaphores

`z.usp_AcquireSemaphore` takes `@SemaphoreName`, total capacity (default 1) and owner (default Transaction). The name identifies the shared semaphore that coordinates callers. It obtains an intent-exclusive application lock on that name and an exclusive slot lock named `<slot>-<SemaphoreName>`. It stores the slot in session context and returns the positive slot as its procedure return value. Detected repeated acquisition prints an informational message and returns -1 without raising an error. Callers should check the return value before proceeding.

It polls slots every four milliseconds indefinitely, without positive-capacity validation or overall timeout. Transaction ownership needs an open transaction. Session ownership requires explicit release/session termination. Application-lock return codes and release results are not fully validated; a failure after the resource lock is acquired can leave Session locks held. All participants must use the same semaphore name, owner and capacity. Session-context keys have a separate length limit, so accepted parameter length alone does not ensure a successful acquisition.

`z.usp_ReleaseSemaphore` takes the same `@SemaphoreName`, reads session context and releases slot and semaphore locks. It does not clear the context or inspect release return codes. These routines do not start a transaction. Ordinary application-lock access is required.

The first parameter was formerly named `@Resource`. Update named-parameter calls to `@SemaphoreName`; positional calls continue to work. The underlying SQL Server application-lock procedures still use their own `@Resource` parameter.

## Trigger flags

`z.usp_SkipTrigger` stores `SkipTriggerFlag` from comma-separated parent/trigger names, or literal `all`. Calling without arguments stores null to clear it.

`z.fn_ShouldSkipTrigger` returns bit for a trigger ID. A trigger must explicitly call it and return early; the procedure does not disable catalog triggers. This is not a permission boundary. Context persists on the same connection and should be reset after use. Catalog visibility governs selected triggers.
