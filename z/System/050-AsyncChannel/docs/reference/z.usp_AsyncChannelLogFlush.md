# z.usp_AsyncChannelLogFlush

[AsyncChannel](../readme.md) | [Reference](readme.md) | [Source](../../modules/1040%20Procedures/z.usp_AsyncChannelLogFlush.sql)

## Purpose and behavior

Saves the current connection's buffered AsyncChannel diagnostics in `z.AsyncChannelLog`. Call it after committing or rolling back processing when you want its buffered messages to become persistent. It does nothing while a transaction is still open.

## Parameters and defaults

None.

## Results and side effects

No result set or explicit return-code contract. Saves up to 40 buffered messages and clears each successfully saved entry. Buffered Info/Payload values are already truncated by the logging procedure. If additional messages were dropped because the buffer was full, it saves a Warning with that count.

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
