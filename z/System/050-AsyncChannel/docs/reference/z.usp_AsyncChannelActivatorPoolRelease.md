# z.usp_AsyncChannelActivatorPoolRelease

[AsyncChannel](../readme.md) | [Reference](readme.md) | [Source](../../modules/1040%20Procedures/z.usp_AsyncChannelActivatorPoolRelease.sql)

## Purpose and behavior

Releases the processing place reserved by `z.usp_AsyncChannelActivatorPoolAcquire`, allowing another session to use that pool's capacity. Call it on the same SQL connection after processing finishes, supplying the pool ID and slot returned by acquisition.

## Parameters and defaults

```text
@ActivatorPoolID int
@Slot int
```

Both parameters are required. A NULL pool ID or slot is a successful no-op, so a bypassed acquisition can use the same cleanup call.

## Results and return codes

No result set. The procedure returns the shared release helper's integer result for the supplied Session-owned slot. Missing or already-released permits return `0`. The helper returns a native negative release status and propagates exceptions under the default `@SuppressException = 0`.

## Transactions, permissions, and limits

Release must run in the acquiring SQL session. Use the pool ID and slot returned at acquisition even if channel configuration has since changed. Transaction completion alone does not release this Session-owned permit. If a repeated acquisition returned the same held slot, release it once. Nested processing must preserve the outer operation's release boundary.

Requires the underlying shared helper's applicable execution permission context.

## Dependencies

`z.usp_ReleaseSemaphore`; the corresponding acquire operation is `z.usp_AsyncChannelActivatorPoolAcquire`.

See [architecture](../architecture.md) for message flow, ownership and operational limits.
