# z.usp_AsyncChannelSend

[AsyncChannel](../readme.md) | [Reference](readme.md) | [Source](../../modules/1040%20Procedures/z.usp_AsyncChannelSend.sql)

## Purpose and behavior

Send already serialized Unicode JSON fragments as `/SchemaZ/AsyncChannel/Message` on a channel conversation. Obtain a conversation through `z.usp_AsyncChannelGetConversationHandle` when the supplied handle is NULL.

## Parameters and defaults

```text
@AsyncChannelID int
@Data nvarchar(max)
@ConversationHandle uniqueidentifier = null output
```

`@Data` is serialized fragment text, for example one JSON object or comma-separated objects without an enclosing batch array. Match the destination channel's payload contract. The helper performs no JSON serialization or content validation. `@ConversationHandle` can return the resolved/replacement handle and can accept an existing handle on entry.

## Results and side effects

No result set or explicit delivery-status return contract. If handle resolution returns NULL, an existing inactive channel discards the message silently; an unknown channel logs an Error and returns. A supplied non-NULL handle bypasses initial channel lookup, so it must belong to the intended channel.

On the first native error 8426, delete the calling session's saved channel conversation, resolve a fresh handle and retry once. Other send errors, or another 8426 after that retry, are rethrown. Logging can also throw.

## Transactions, permissions, and limits

SEND participates in the current transaction; delivery follows commit and does not mean application processing has finished. The helper starts no transaction around SEND, while conversation resolution uses its own nested transaction and can roll back caller work on failure. Requires applicable SEND/conversation permissions and access to the registry/logging chain.

## Example

For an existing deployed channel whose interface contains RecordID:

```sql
exec z.usp_AsyncChannelSend @AsyncChannelID = 100, @Data = N'{"RecordID":1}';
```

## Dependencies

`z.usp_AsyncChannelGetConversationHandle`, `z.AsyncChannel`, `z.AsyncChannelSession`, `z.usp_AsyncChannelLog`, and `/SchemaZ/AsyncChannel/Message`.

See [architecture](../architecture.md) for message flow, ownership and operational limits.
