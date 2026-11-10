# /SchemaZ/AsyncChannel/Sender

[AsyncChannel](../readme.md) | [Reference](readme.md) | [Source](../../baseline/1040%20ServiceBroker/SenderInfrastructure.sql)

## Purpose and definition

The shared Service Broker service used as the initiator of channel conversations. Its exact database-scoped Broker name is `/SchemaZ/AsyncChannel/Sender`.

The guarded baseline creates it when absent, binds it to [z.AsyncChannelSenderQueue](z.AsyncChannelSenderQueue.md), and associates it with the [/SchemaZ/AsyncChannel/Contract](SchemaZ.AsyncChannel.Contract.md) contract. `z.usp_AsyncChannelGetConversationHandle` begins conversations from this service to the selected channel's generated target service in the current database.

## Message flow

Application messages travel to the target channel queue. Conversation end/error messages arriving at the shared sender queue are consumed by [z.usp_AsyncChannelSenderActivator](z.usp_AsyncChannelSenderActivator.md), which ends local conversations and removes matching session-registry entries. This service does not receive and process application payload batches for every channel; those belong to the generated per-channel services and activators.

## Permissions and limits

Service creation requires applicable database Service Broker DDL permissions and access to its queue and contract. Existing services are retained without repairing their queue or contract associations. Delivery requires database Service Broker enabled; the installer does not enable it or create application channels.

See [architecture](../architecture.md) and [conversation lookup](z.usp_AsyncChannelGetConversationHandle.md).
