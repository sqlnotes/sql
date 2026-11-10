# z.usp_AsyncChannelActivatorPoolRelease

[AsyncChannel](../readme.md) | [Reference](readme.md) | [Source](../../modules/1040%20Procedures/z.usp_AsyncChannelActivatorPoolRelease.sql)

## Purpose and behavior

Release the Session-owned processing permit for an acquired activator pool through `z.usp_ReleaseSemaphore`. The shared helper obtains the held slot from session context; callers supply only the pool ID returned by acquisition.

## Parameters and defaults

```text
@ActivatorPoolID int
```

NULL is accepted as a no-op, allowing an unlimited/bypassed acquisition to use the same cleanup path. There is no default value.

## Results and return codes

No result set. For a non-NULL pool ID, return the shared release helper's integer result. A NULL argument returns normally without invoking the helper. Missing/invalid ownership context for a non-NULL ID can throw; repeated release is not a guaranteed no-op.

## Transactions, permissions, and limits

Release must run in the acquiring SQL session. Use the ID returned at acquisition, even if channel configuration has since changed. Transaction completion alone does not release this Session-owned permit. A single release also ends a same-session repeated acquisition because acquisition does not add lock references. Nested processing must preserve the outer operation's release boundary.

Requires the underlying shared helper's applicable execution permission context. Native release failures propagate through the helper result or exception.

## Dependencies

`z.usp_ReleaseSemaphore`; the corresponding acquire operation is `z.usp_AsyncChannelActivatorPoolAcquire`.

See [architecture](../architecture.md) for message flow, ownership and operational limits.
