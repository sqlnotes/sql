# z.usp_AsyncChannelActivatorPoolAcquire

[AsyncChannel](../readme.md) | [Reference](readme.md) | [Source](../../modules/1040%20Procedures/z.usp_AsyncChannelActivatorPoolAcquire.sql)

## Purpose and behavior

Reserves one processing place in the pool assigned to a channel. Use it before processing work when several channels must share a concurrency limit. Keep the returned pool ID and slot for the matching release. Generated channel activators already perform this acquisition and release.

Pool capacity comes from `MaxConcurrency` and is shared across its channels. The reservation uses a Session-owned System semaphore named `ADPool/<ActivatorPoolID>`, so transaction completion alone does not release it.

## Parameters and defaults

```text
@AsyncChannelID int
@ActivatorPoolID int output
@Slot int output
```

`@AsyncChannelID` identifies the channel whose pool is resolved. `@ActivatorPoolID` and `@Slot` are cleared at entry. After a successful shared-semaphore acquisition, they receive the pool ID and its acquired slot.

## Results and return codes

No result set. Return code `0` means either a permit was acquired (both outputs populated) or no limit was applied (both outputs NULL). Missing channel/pool, an inactive pool, and zero capacity all bypass acquisition. The wrapper does not independently test the channel's `IsActive` flag.

A nonpositive shared-helper result produces a Warning log and return code `-1`, with both outputs NULL. Helper and logging exceptions can propagate instead of returning `-1`.

## Transactions, permissions, and limits

The permit survives transaction commit or rollback because it is Session-owned. Pass both outputs to `z.usp_AsyncChannelActivatorPoolRelease` in the same session after the outer processing operation finishes. While configured capacity still includes the held slot, another acquisition in the same session returns that slot without adding a reference. Nested callers leave release to the outer owner. If the pool stays active and its positive capacity shrinks below the held slot, repeated acquisition raises error `50000`. Use the original pool ID and slot to release the permit before acquiring again.

`TimeoutSeconds = -1` waits indefinitely. Finite seconds are converted to milliseconds and capped at 2147483647. The pool view infers waiters from legacy intent-exclusive markers. The current helper does not acquire those markers, so its waiters contribute zero to `SessionsWaiting`. If cancellation leaves a Session-owned slot held, use the acquired pool ID and slot to release it on the same connection. Disconnecting also releases the slot. Requires access to the registry and the underlying shared helper and logging operations through the applicable permission context.

## Dependencies

`z.AsyncChannel`, `z.AsyncChannelActivatorPool`, `z.usp_AcquireSemaphore`, and `z.usp_AsyncChannelLog`.

See [architecture](../architecture.md) for message flow, ownership and operational limits.
