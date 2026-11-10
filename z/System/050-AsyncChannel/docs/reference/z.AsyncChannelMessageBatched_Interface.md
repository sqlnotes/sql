# z.AsyncChannelMessageBatched_Interface

[AsyncChannel](../readme.md) | [Reference](readme.md) | [Source](../../modules/1020%20Views/z.AsyncChannelMessageBatched_Interface.sql)

## Purpose and columns

A shared insert interface that batches already serialized JSON fragments by destination channel. The view uses `select top 0` and always reads as an empty set.

| Column | Type | Meaning |
| --- | --- | --- |
| AsyncChannelID | int | Destination channel ID |
| DataSequence | bigint | Ordering key used within channel chunks |
| Data | nvarchar(max) | Serialized JSON fragment |

All expressions are nullable casts; the view itself declares no required-value checks.

## Insert behavior and limits

[z.TRI_AsyncChannelMessageBatched_Interface](z.TRI_AsyncChannelMessageBatched_Interface.md) joins inserted rows to active registered channels, chunks rows by MaxRowsPerMessage and joins fragment text with commas. A NULL row limit uses 2147483647 for chunking. Each chunk is sent as one message.

Unknown or inactive channel rows are filtered out by the trigger's join, rather than passed to the send helper. DataSequence ties have no guaranteed order. STRING_AGG omits NULL Data values; no JSON serialization or validation is performed. Supply fragments matching the channel codec without a surrounding batch array.

Sends participate in the inserting transaction. Reading the view shows neither stored data nor queue contents. See [architecture](../architecture.md) for message delivery, processing and transaction limits.
