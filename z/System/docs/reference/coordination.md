# Semaphores and trigger flags

[Object index](readme.md) · [Declarations and sources](procedures.md)

## Semaphores

`z.usp_AcquireSemaphore` takes resource, total capacity (default 1) and owner (default Transaction). It obtains an intent-exclusive resource application lock and an exclusive slot lock named `<slot>-<resource>`. It stores the slot in session context and returns the positive slot as its procedure return value. Detected repeated acquisition raises an error and returns -1.

It polls slots every four milliseconds indefinitely, without positive-capacity validation or overall timeout. Transaction ownership needs an open transaction. Session ownership requires explicit release/session termination. All participants must use the same resource, owner and capacity.

`z.usp_ReleaseSemaphore` reads session context and releases slot and resource locks. It does not clear the context or inspect release return codes. These routines do not start a transaction. Ordinary application-lock access is required.

## Trigger flags

`z.usp_SkipTrigger` stores `SkipTriggerFlag` from comma-separated parent/trigger names, or literal `all`. Calling without arguments stores null to clear it.

`z.fn_ShouldSkipTrigger` returns bit for a trigger ID. A trigger must explicitly call it and return early; the procedure does not disable catalog triggers. This is not a permission boundary. Context persists on the same connection and should be reset after use. Catalog visibility governs selected triggers.
