# /SchemaZ/AsyncChannel/Message

[AsyncChannel](../readme.md) | [Reference](readme.md) | [Source](../../baseline/1030%20ServiceBroker/MessageAndContract.sql)

## Purpose and definition

The shared Service Broker message type used for AsyncChannel application payloads. Its exact name is `/SchemaZ/AsyncChannel/Message`; it is a database-scoped Broker object rather than a schema-qualified SQL object.

The baseline creates it only when that name is absent, with `validation = none`. The framework sends Unicode JSON fragments, but the message type does not validate their content. Callers must supply payloads compatible with the channel's interface and processing procedure.

## Use and dependencies

The [AsyncChannel contract](SchemaZ.AsyncChannel.Contract.md) permits this message type from the initiator. The [shared sender service](SchemaZ.AsyncChannel.Sender.md) initiates conversations to generated per-channel target services. Generated activators identify rows of this message type as `IsPayload = 1` in the [message table type](z.AsyncChannelMessage.md).

The Broker message type and `z.AsyncChannelMessage` serve different purposes: the former identifies messages on a conversation; the latter is the typed batch passed to application processing procedures.

## Permissions and limits

Creating this object requires the applicable database Service Broker DDL permissions. Delivery requires Service Broker enabled in the database; installation does not enable it. An existing message type is retained without repairing its definition.

See [architecture](../architecture.md) for the send/receive diagrams, transaction behavior and payload limitations.
