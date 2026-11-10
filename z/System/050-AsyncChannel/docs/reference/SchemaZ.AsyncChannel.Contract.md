# /SchemaZ/AsyncChannel/Contract

[AsyncChannel](../readme.md) | [Reference](readme.md) | [Source](../../baseline/1030%20ServiceBroker/MessageAndContract.sql)

## Purpose and definition

The shared Service Broker contract for AsyncChannel conversations. Its exact database-scoped Broker name is `/SchemaZ/AsyncChannel/Contract`.

The baseline creates it only when absent. The contract permits [/SchemaZ/AsyncChannel/Message](SchemaZ.AsyncChannel.Message.md) messages `sent by initiator`. Application payload messages flow from the shared sender to a channel's target service; this contract does not define an application reply message type. Broker system messages, including conversation end/error notifications, are handled separately.

## Use and dependencies

The [shared sender service](SchemaZ.AsyncChannel.Sender.md) and generated per-channel target services use this contract. `z.usp_AsyncChannelGetConversationHandle` selects it when beginning a channel conversation. The message type must exist before the contract is created; the contract must exist before the service definitions that reference it.

## Permissions and limits

Creating the contract requires applicable database Service Broker DDL permissions. An existing contract is retained without reconciling its message permissions. The contract does not validate JSON or define processing logic.

See [architecture](../architecture.md) for channel ownership and conversation behavior.
