# z.usp_AsyncChannelForward

[AsyncChannel](../readme.md) | [Reference](readme.md) | [Source](../../modules/1040%20Procedures/z.usp_AsyncChannelForward.sql)

## Purpose and behavior

Forward only rows with `IsPayload = 1` from a received message table to each selected destination channel. Timer/control rows are ignored. Payload text is forwarded without decoding or transforming it, so destinations must accept its format.

## Parameters and defaults

```text
@Messages z.AsyncChannelMessage readonly
@AsyncChannelIDs varchar(max)
@Batched bit = 1
```

`@AsyncChannelIDs` is a comma-separated list of integer IDs. Spaces and empty tokens are ignored, and duplicates are removed. Noninteger tokens fail conversion. With `@Batched = 0`, insert through `z.AsyncChannelMessage_Interface`; otherwise use `z.AsyncChannelMessageBatched_Interface`, which chunks according to destination configuration.

## Results and side effects

No defined result set or explicit return-code contract. Unknown destination IDs are logged at Error level and removed from the destination list; known destinations continue. Error attribution uses the source channel ID from `AsyncChannel-AsyncChannelID` session context. Each forwarded row carries its original `SequenceNumber` as `DataSequence`.

## Transactions, permissions, and limits

No explicit transaction is started. Forwarded SEND operations participate in the caller's transaction, commonly the receiving activator's transaction. Conversion, trigger, send and logging exceptions can propagate. Destination inactive-send behavior follows the shared send helper. Requires access to the shared interface insert/trigger/send chain under the applicable permission context.

## Dependencies

`z.AsyncChannelMessage`, `z.AsyncChannel`, `z.AsyncChannelMessage_Interface`, `z.AsyncChannelMessageBatched_Interface`, and `z.usp_AsyncChannelLog`.

See [architecture](../architecture.md) for message flow, ownership and operational limits.
