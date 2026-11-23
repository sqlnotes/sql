# z.TRI_AsyncChannelMessage_Interface

[AsyncChannel](../readme.md) | [Reference](readme.md) | [Source](../../modules/1060%20Triggers/z.TRI_AsyncChannelMessage_Interface.sql)

## Target and behavior

Sends each JSON fragment inserted into [z.AsyncChannelMessage_Interface](z.AsyncChannelMessage_Interface.md) as a separate channel message. Applications use the interface INSERT; they do not call this trigger directly. Rows are processed by channel and DataSequence, without being stored in the interface view.

It uses the shared conversation and send helpers to deliver the fragments to their configured channel. Choose the [batched interface](z.AsyncChannelMessageBatched_Interface.md) instead when several fragments should share a message.

## Input and results

Uses AsyncChannelID, DataSequence and Data from `inserted`; there are no explicit parameters or defined result sets. DataSequence only orders the current inserted set. Duplicate sequence values do not establish deterministic order. Each Data value is sent unchanged as a separate message, even if MaxRowsPerMessage is configured.

## Dependencies, transactions and limits

Depends on the target interface and the conversation/send helpers. It does not validate JSON or independently log missing channels. If conversation lookup returns no handle, that channel's rows are skipped. Native/helper errors can propagate; there is no trigger-local TRY/CATCH.

Runs within the INSERT transaction. Delivery requires commit, and helper failure paths can roll back caller work. Use the [batched interface](z.AsyncChannelMessageBatched_Interface.md) when multiple fragments should be combined according to the channel limit. See [architecture](../architecture.md) for further limits.
