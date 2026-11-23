# z.usp_AsyncChannelActivatorPoolRelease

[AsyncChannel](../readme.md) | [Reference](readme.md) | [Source](../../modules/1040%20Procedures/z.usp_AsyncChannelActivatorPoolRelease.sql)

## Purpose and behavior

Releases the processing place reserved by `z.usp_AsyncChannelActivatorPoolAcquire`, allowing another session to use that pool's capacity. Call it on the same SQL connection after processing finishes, supplying the pool ID returned by acquisition. The shared semaphore helper tracks the held reservation; callers do not need a slot number.

## Parameters and defaults

```text
@ActivatorPoolID int
```

NULL is accepted as a no-op, allowing an unlimited/bypassed acquisition to use the same cleanup path. There is no default value.

## Results and return codes

No result set. For a non-NULL pool ID, return the shared release helper's integer result. A NULL argument returns normally without invoking the helper. Missing or already-released permits are successful no-ops. The helper uses the recorded owner, returns any negative native release status, and propagates exceptions under the default `@SuppressException = 0`.

## Transactions, permissions, and limits

Release must run in the acquiring SQL session. Use the ID returned at acquisition, even if channel configuration has since changed. Transaction completion alone does not release this Session-owned permit. A single release also ends a same-session repeated acquisition because acquisition does not add lock references. Nested processing must preserve the outer operation's release boundary.

Requires the underlying shared helper's applicable execution permission context.

## Dependencies

`z.usp_ReleaseSemaphore`; the corresponding acquire operation is `z.usp_AsyncChannelActivatorPoolAcquire`.

See [architecture](../architecture.md) for message flow, ownership and operational limits.
