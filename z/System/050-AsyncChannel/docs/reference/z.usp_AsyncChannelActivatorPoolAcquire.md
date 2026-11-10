# z.usp_AsyncChannelActivatorPoolAcquire

[AsyncChannel](../readme.md) | [Reference](readme.md) | [Source](../../modules/1040%20Procedures/z.usp_AsyncChannelActivatorPoolAcquire.sql)

## Purpose and behavior

Resolve a channel's configured pool and acquire a processing permit through `z.usp_AcquireSemaphore`. The semaphore is named `ADPool/<ActivatorPoolID>`, uses Session ownership, and takes its capacity from `MaxConcurrency`. Different channels assigned to the same pool share that capacity.

## Parameters and defaults

```text
@AsyncChannelID int
@ActivatorPoolID int output
```

`@AsyncChannelID` identifies the channel whose pool is resolved. `@ActivatorPoolID` is cleared at entry and populated only after a positive shared-semaphore acquisition result; it is the pool ID, not a slot number.

## Results and return codes

No result set. Return code `0` means either a permit was acquired (non-NULL output) or no limit was applied (NULL output). Missing channel/pool, an inactive pool, and zero capacity all bypass acquisition. The wrapper does not independently test the channel's `IsActive` flag.

A nonpositive shared-helper result produces a Warning log and return code `-1`, with NULL output. Helper and logging exceptions can propagate instead of returning `-1`.

## Transactions, permissions, and limits

The permit survives transaction commit or rollback because it is Session-owned. Release the acquired pool ID through `z.usp_AsyncChannelActivatorPoolRelease` in the same session after the outer processing operation finishes. Repeated same-session acquisition returns the held slot without adding a reference; nested callers must leave release to the outer owner.

`TimeoutSeconds = -1` waits indefinitely. Finite seconds are converted to milliseconds and capped at 2147483647. Cancellation can leave a main marker without a slot until disconnect; the pool view can count that marker as a waiter. Requires access to the registry and the underlying shared helper and logging operations through the applicable permission context.

## Dependencies

`z.AsyncChannel`, `z.AsyncChannelActivatorPool`, `z.usp_AcquireSemaphore`, and `z.usp_AsyncChannelLog`.

See [architecture](../architecture.md) for message flow, ownership and operational limits.
