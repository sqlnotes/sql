# z.AsyncChannelMessage_Interface

[AsyncChannel](../readme.md) | [Reference](readme.md) | [Source](../../modules/1020%20Views/z.AsyncChannelMessage_Interface.sql)

## Purpose and columns

A shared insert interface for already serialized JSON fragments. The view is defined as `select top 0`, so reading it always returns an empty set; it is not a stored message table.

| Column | Type | Meaning |
| --- | --- | --- |
| AsyncChannelID | int | Destination channel ID |
| DataSequence | bigint | Ordering key within this INSERT's channel rows |
| Data | nvarchar(max) | Serialized JSON fragment |

All three expressions are nullable casts. The view itself imposes no required-value validation.

## Insert behavior and dependencies

[z.TRI_AsyncChannelMessage_Interface](z.TRI_AsyncChannelMessage_Interface.md) intercepts INSERT, orders by channel ID and DataSequence, obtains/reuses each channel conversation and invokes the send helper once per input row. It does not use MaxRowsPerMessage to combine rows.

Provide JSON fragments matching the destination codec, without adding a surrounding array for the complete batch. The interface does not serialize typed columns or validate JSON. Duplicate DataSequence values do not guarantee a tie order. Sends participate in the inserting transaction and become deliverable after commit.

See the trigger and [architecture](../architecture.md) for inactive/unknown channels, helper failures and rollback behavior. INSERT into this view invokes work; SELECT does not expose queue contents or processing status.
