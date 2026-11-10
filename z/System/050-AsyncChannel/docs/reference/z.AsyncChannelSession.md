# z.AsyncChannelSession

[AsyncChannel](../readme.md) | [Reference](readme.md) | [Source](../../baseline/1020%20Tables/z.AsyncChannelSession.sql)

## Purpose and behavior

Tracks reusable sender conversation handles per channel and SQL session. [z.usp_AsyncChannelGetConversationHandle](z.usp_AsyncChannelGetConversationHandle.md) creates or updates registrations; sender activation and channel removal clean them up. Installation creates the table when absent.

## Columns and keys

| Column | Type | Required | Meaning |
| --- | --- | --- | --- |
| AsyncChannelID | int | Yes | Channel identifier |
| SessionID | smallint | Yes | Sending SQL session ID |
| GroupBucket | smallint | Yes | Sender grouping bucket used to select related conversations |
| ConversationHandle | uniqueidentifier | Yes | Broker conversation handle |
| StartTimeUTC | datetime2(7) | Yes | UTC start time recorded when the registry entry is written |

The clustered primary key is `(AsyncChannelID, SessionID)`. ConversationHandle has a unique nonclustered constraint. A nonclustered index on `(AsyncChannelID, GroupBucket)` supports grouping lookup. There are no column defaults or foreign keys.

## Side effects and limits

This is framework bookkeeping, not a list of currently connected sessions or a delivery ledger. Session IDs may be reused, so a row alone does not prove that the current connection owns a usable conversation. The conversation helper reuses a matching channel/session registration when its grouping bucket is unchanged; it does not validate endpoint state on that path. Stale-conversation send recovery can delete and recreate a registration after error 8426.

Directly deleting a row does not end its Broker conversation. Use the framework lifecycle procedures instead of treating table deletion as conversation cleanup. See [architecture](../architecture.md) for transaction ownership and forced-removal behavior.
