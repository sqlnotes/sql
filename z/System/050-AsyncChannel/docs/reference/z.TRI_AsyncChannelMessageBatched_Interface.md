# z.TRI_AsyncChannelMessageBatched_Interface

[AsyncChannel](../readme.md) | [Reference](readme.md) | [Source](../../modules/1060%20Triggers/z.TRI_AsyncChannelMessageBatched_Interface.sql)

## Target and behavior

Combines JSON fragments inserted into [z.AsyncChannelMessageBatched_Interface](z.AsyncChannelMessageBatched_Interface.md) into messages for each destination channel. Applications use the interface INSERT; they do not call this trigger directly. Only active registered channels receive messages.

Within each channel, DataSequence determines fragment order and MaxRowsPerMessage determines the largest chunk. A NULL limit uses 2147483647 rows for chunking. Each chunk's fragments are joined with commas and sent as one message through the shared conversation/send helpers.

## Inputs, dependencies and limits

Consumes AsyncChannelID, DataSequence and Data from `inserted`; no explicit parameters or defined result sets. Depends on the interface view, channel registry and conversation/send helpers.

Unknown/inactive channels are silently filtered out. NULL Data is omitted by STRING_AGG, and equal DataSequence values have no guaranteed tie order. No JSON validation or typed serialization occurs; values must already be suitable JSON fragments without the surrounding batch array. Input rows are not persisted in the view.

Runs inside the inserting transaction, and sends require commit for delivery. It has no local TRY/CATCH; helper/native errors can propagate or roll back caller work. See [architecture](../architecture.md) for transaction and retry limits.
