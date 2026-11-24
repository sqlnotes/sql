# z.usp_AsyncChannelGetConversationHandle

[AsyncChannel](../readme.md) | [Reference](readme.md) | [Source](../../modules/1040%20Procedures/z.usp_AsyncChannelGetConversationHandle.sql)

## Purpose and behavior

Returns a conversation handle that the current SQL session can use to send work to an active channel. It reuses the session's saved conversation when the channel's grouping still matches, or creates a replacement when needed. Sending helpers use this procedure so callers usually do not need to manage conversation creation themselves.

Conversations run between the shared sender service and the channel's target service in the current database, using the AsyncChannel contract with encryption off. Grouping depends on the sending session and the channel's Readers setting.

## Parameters and defaults

```text
@AsyncChannelID int
@ConversationHandle uniqueidentifier output
@MaxRowsPerMessage int = null output
```

Both outputs are cleared at entry. NULL, unknown or inactive channel IDs return a NULL handle. For an active channel, `@MaxRowsPerMessage` returns its configured batching value, including NULL. The procedure does not send application data.

## Results and side effects

No result set or explicit return-code contract. A new/replacement conversation is saved in `z.AsyncChannelSession`; a saved handle is reused when its bucket matches. A replaced non-NULL handle is ended. The helper does not independently validate the endpoint state of a reused handle; the send paths handle one stale-conversation error.

## Transactions, permissions, and limits

The procedure begins and commits a transaction, acquiring a binary Transaction-owned semaphore with an indefinite wait. The semaphore remains held until the actual outer transaction ends, including when this procedure was called inside a caller transaction. Catch rolls back the entire active transaction and rethrows, which can roll back caller work.

Requires applicable Service Broker dialog/service permissions and access to registry/semaphore operations. The configured target service must already exist for a usable channel. Conversation grouping does not promise global ordering across sessions.

## Dependencies

`z.AsyncChannel`, `z.AsyncChannelSession`, `z.v_AsyncChannel`, `z.usp_AcquireSemaphore`, `/SchemaZ/AsyncChannel/Sender`, and `/SchemaZ/AsyncChannel/Contract`.

See [architecture](../architecture.md) for message flow, ownership and operational limits.
