# z.TRI_AsyncChannelMessageBatched_Interface

[AsyncChannel](../readme.md) | [Reference](readme.md) | [Source](../../modules/1060%20Triggers/z.TRI_AsyncChannelMessageBatched_Interface.sql)

## Target and behavior

An `instead of insert` trigger on [z.AsyncChannelMessageBatched_Interface](z.AsyncChannelMessageBatched_Interface.md). Empty inserted sets return immediately. It joins inserted rows to `z.AsyncChannel`, retaining only registered channels with IsActive = 1.

For each channel it assigns a row number ordered by DataSequence, divides rows into chunks using MaxRowsPerMessage (2147483647 when NULL), and builds each payload with `string_agg(Data, N',')` ordered by DataSequence. A local static cursor visits channel/chunk order, obtains a conversation handle on each channel change and invokes `z.usp_AsyncChannelSend` once per chunk when a handle exists.

## Inputs, dependencies and limits

Consumes AsyncChannelID, DataSequence and Data from `inserted`; no explicit parameters or defined result sets. Depends on the interface view, channel registry and conversation/send helpers.

Unknown/inactive channels are silently filtered out. NULL Data is omitted by STRING_AGG, and equal DataSequence values have no guaranteed tie order. No JSON validation or typed serialization occurs; values must already be suitable JSON fragments without the surrounding batch array. Input rows are not persisted in the view.

Runs inside the inserting transaction, and sends require commit for delivery. It has no local TRY/CATCH; helper/native errors can propagate or roll back caller work. See [architecture](../architecture.md) for transaction and retry limits.
