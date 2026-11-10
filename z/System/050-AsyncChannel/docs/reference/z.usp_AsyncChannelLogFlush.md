# z.usp_AsyncChannelLogFlush

[AsyncChannel](../readme.md) | [Reference](readme.md) | [Source](../../modules/1040%20Procedures/z.usp_AsyncChannelLogFlush.sql)

## Purpose and behavior

Drain the current session's buffered AsyncChannel diagnostics into `z.AsyncChannelLog`. Return immediately when any transaction is open; flush explicitly after the caller's transaction has ended when necessary.

## Parameters and defaults

None.

## Results and side effects

No result set or explicit return-code contract. Read at most the first 40 numbered session-context slots, insert their metadata and truncated Info/Payload values, and clear each successfully inserted slot. If the buffered count exceeds 40, append a Warning reporting the dropped count. Finally clear `AsyncChannel-LogCount`.

## Transactions, permissions, and limits

No all-or-nothing flush transaction is started. Insert or session-context errors propagate and can leave a partially flushed buffer; do not assume an interrupted flush is atomic. No work is done if a transaction remains open. Session closure discards any unflushed entries. Requires applicable table-insert and session-context permissions under the execution context.

## Example

After committing or rolling back the caller's transaction:

```sql
exec z.usp_AsyncChannelLogFlush;
```

## Dependencies

`z.AsyncChannelLog`; buffer entries are created by `z.usp_AsyncChannelLog`.

See [architecture](../architecture.md) for message flow, ownership and operational limits.
