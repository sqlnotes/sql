# z.AsyncChannelMessage

[AsyncChannel](../readme.md) | [Reference](readme.md) | [Source](../../baseline/1010%20Types/z.AsyncChannelMessage.sql)

## Purpose and schema

A table type carrying one received message batch to an application processing procedure, or supplying rows to the forwarding helper. Installation creates the type only when absent.

| Column | Type | Required | Meaning |
| --- | --- | --- | --- |
| ConversationHandle | uniqueidentifier | Yes | Native conversation handle |
| MessageTypeID | int | Yes | Native Service Broker message type ID |
| SequenceNumber | bigint | Yes | Native sequence number within the conversation |
| IsPayload | bit | Yes | `1` for application payload messages; `0` for control or timer messages |
| Payload | nvarchar(max) | No | Message body converted to Unicode text |

The type declares no keys, indexes or defaults. A procedure parameter of this type is passed `readonly`.

## Processing contract

Generated activators populate the type from `RECEIVE`. Processing runs for a batch containing payload or DialogTimer messages and receives the entire batch, which can also include other control rows already handled by the activator. Decode only `IsPayload = 1` rows using the channel's generated deserializer; timer and control rows are not application JSON.

One payload message may contain several comma-separated JSON fragments. SequenceNumber describes a conversation's order, not a global order across sessions; selecting from a table variable without an explicit ordering does not establish an output order.

See [architecture](../architecture.md) for the receive transaction, pool admission, rollback and retry path. Application processing should account for retries and caller-wide rollback behavior.
