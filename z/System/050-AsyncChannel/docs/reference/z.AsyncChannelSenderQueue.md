# z.AsyncChannelSenderQueue

[AsyncChannel](../readme.md) | [Reference](readme.md) | [Queue source](../../baseline/1040%20ServiceBroker/SenderInfrastructure.sql) | [Activation source](../../modules/1050%20ServiceBroker/Sender.sql)

## Purpose and definition

The shared reply queue for [/SchemaZ/AsyncChannel/Sender](SchemaZ.AsyncChannel.Sender.md). It receives sender-side conversation notifications; each generated channel has a separate target queue for its application work.

The baseline creates the queue only when absent, with `status = on`, `retention = off` and `poison_message_handling (status = off)`. Existing queues are retained rather than recreated.

## Activation

The later sender-binding script configures activation after [z.usp_AsyncChannelSenderActivator](z.usp_AsyncChannelSenderActivator.md) exists. It checks the activation state, procedure, reader count and execution principal, then applies:

| Setting | Value |
| --- | --- |
| Activation status | On |
| Procedure | `z.usp_AsyncChannelSenderActivator` |
| Maximum queue readers | `1` |
| Execution context | Queue owner |

The activator consumes Broker EndDialog/Error messages, ends the sender conversation and deletes corresponding rows from [z.AsyncChannelSession](z.AsyncChannelSession.md). Error notifications are logged through `z.usp_AsyncChannelLog`.

## Permissions and limits

Creating and altering the queue requires applicable database DDL permissions. Activation runs as owner and requires the permissions needed by the activated procedure. Poison-message handling is disabled; monitoring and error handling remain operational responsibilities. The binding script updates activation settings but does not reconcile all queue properties. This queue supplies neither an application response protocol nor a guarantee that processing has completed.

See [architecture](../architecture.md) for the complete message flow.
