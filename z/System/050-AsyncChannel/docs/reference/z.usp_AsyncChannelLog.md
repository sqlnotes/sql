# z.usp_AsyncChannelLog

[AsyncChannel](../readme.md) | [Reference](readme.md) | [Source](../../modules/1040%20Procedures/z.usp_AsyncChannelLog.sql)

## Purpose and behavior

Write one diagnostic row directly, or buffer it in session context while a transaction is open. Outside a transaction, first flush any retained buffer and then insert the current row. Debug rows are inserted directly in the current transaction and are skipped when the transaction is doomed.

## Parameters and defaults

```text
@AsyncChannelID int = null
@Level varchar(20) = null
@Info nvarchar(max) = null
@Payload nvarchar(max) = null
@SessionID smallint = null
@ConversationHandle uniqueidentifier = null
```

All fields are optional and are stored as supplied; the procedure does not automatically substitute `@@spid` for a NULL `@SessionID`. `Debug` receives the special transaction behavior described above. Other levels are not validated against an enumeration.

## Results and side effects

No result set or explicit return-code contract. Non-Debug rows inside a transaction use `AsyncChannel-LogCount` and per-slot metadata/text session keys. The first 40 rows are retained; buffered Info and Payload are each truncated to 4,000 characters. Additional rows are dropped but counted for a warning on flush.

## Transactions, permissions, and limits

The procedure starts no transaction. Session-buffered entries survive rollback but are lost on disconnect unless flushed first. Debug rows roll back with the transaction. Buffering errors are suppressed; direct table insert and flush errors can propagate. This is not an autonomous committed logging guarantee.

Requires the applicable log-table/flush/session-context permission context. Direct insertion allocates the table's default log identifier.

## Example

```sql
exec z.usp_AsyncChannelLog @AsyncChannelID = 100, @Level = 'Info', @Info = N'Processing checkpoint';
```

## Dependencies

`z.AsyncChannelLog` and `z.usp_AsyncChannelLogFlush`.

See [architecture](../architecture.md) for message flow, ownership and operational limits.
