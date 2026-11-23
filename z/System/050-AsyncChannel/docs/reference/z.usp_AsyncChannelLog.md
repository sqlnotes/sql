# z.usp_AsyncChannelLog

[AsyncChannel](../readme.md) | [Reference](readme.md) | [Source](../../modules/1040%20Procedures/z.usp_AsyncChannelLog.sql)

## Purpose and behavior

Records a diagnostic message for channel operations in `z.AsyncChannelLog`. You can include the channel, SQL session, conversation and related payload to help investigate processing failures. Non-Debug messages written during a transaction are buffered until they can be flushed outside the transaction, allowing them to survive a rollback on that connection.

Outside a transaction, the procedure saves any buffered messages before the new one. Debug messages instead participate in the current transaction and are skipped when that transaction is uncommittable.

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

No result set or explicit return-code contract. The session buffer retains the first 40 rows; buffered Info and Payload are each limited to 4,000 characters. Additional rows are dropped but counted for a warning on flush.

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
