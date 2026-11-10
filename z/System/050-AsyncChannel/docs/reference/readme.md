# Framework reference

[AsyncChannel](../readme.md)

Only shared framework objects are installed. Per-channel generated objects are created on demand by the generator and remain separate from the framework definitions.

| Object | Responsibility |
| --- | --- |
| [z.usp_CreateDemoAsyncChannel](z.usp_CreateDemoAsyncChannel.md) | Opt-in construction example with usage comments before the definition; creates a manual Demo channel and its authored objects |
| [z.AsyncChannel](z.AsyncChannel.md) | Channel configuration and processing settings |
| [z.AsyncChannelActivatorPool](z.AsyncChannelActivatorPool.md) | Shared concurrency limits and pool wait settings |
| [z.AsyncChannelLog](z.AsyncChannelLog.md) | Persisted diagnostic messages on shared bigint partitions |
| [z.AsyncChannelMessage](z.AsyncChannelMessage.md) | Readonly payload, control and timer message table type |
| [z.AsyncChannelSession](z.AsyncChannelSession.md) | Per-channel, per-session reusable conversations |
| [z.fn_AsyncChannelColumns](z.fn_AsyncChannelColumns.md) | Interface metadata and codec generation expressions |
| [z.fn_AsyncChannelCurrentTimer](z.fn_AsyncChannelCurrentTimer.md) | Remaining seconds for a committed endpoint timer |
| [z.fn_AsyncChannelTypeDef](z.fn_AsyncChannelTypeDef.md) | Type declarations used in signature comparison |
| [z.TRI_AsyncChannelMessage_Interface](z.TRI_AsyncChannelMessage_Interface.md) | Routes inserted fragments to the send helper |
| [z.TRI_AsyncChannelMessageBatched_Interface](z.TRI_AsyncChannelMessageBatched_Interface.md) | Chunks and routes inserted fragments to the send helper |
| [z.usp_AsyncChannelActivatorPoolAcquire](z.usp_AsyncChannelActivatorPoolAcquire.md) | Acquires a Session-owned shared semaphore processing slot |
| [z.usp_AsyncChannelActivatorPoolRelease](z.usp_AsyncChannelActivatorPoolRelease.md) | Releases one matching shared semaphore acquisition |
| [z.usp_AsyncChannelDeploy](z.usp_AsyncChannelDeploy.md) | Executes missing or explicitly forced generated scripts in order |
| [z.usp_AsyncChannelForward](z.usp_AsyncChannelForward.md) | Forwards payload rows to configured destination IDs |
| [z.usp_AsyncChannelGetConversationHandle](z.usp_AsyncChannelGetConversationHandle.md) | Creates or reuses a channel conversation for the calling session |
| [z.usp_AsyncChannelLog](z.usp_AsyncChannelLog.md) | Writes immediately or buffers diagnostic rows in session context |
| [z.usp_AsyncChannelLogFlush](z.usp_AsyncChannelLogFlush.md) | Drains buffered logs when no transaction is open |
| [z.usp_AsyncChannelRemove](z.usp_AsyncChannelRemove.md) | Cleans selected channel conversations and generated artifacts, preserving authored objects |
| [z.usp_AsyncChannelSend](z.usp_AsyncChannelSend.md) | Sends serialized fragments and retries one stale-conversation failure |
| [z.usp_AsyncChannelSenderActivator](z.usp_AsyncChannelSenderActivator.md) | Consumes sender-side end/error messages and clears session registry entries |
| [z.usp_AsyncChannelSetTimer](z.usp_AsyncChannelSetTimer.md) | Arms or replaces an endpoint conversation timer |
| [z.v_AsyncChannel](z.v_AsyncChannel.md) | Resolved channel object names and validation reasons |
| [z.v_AsyncChannelActivatorPool](z.v_AsyncChannelActivatorPool.md) | Pool configuration, granted slots and inferred waiting sessions in the current database |
| [z.AsyncChannelMessage_Interface](z.AsyncChannelMessage_Interface.md) | Shared insert interface sending each serialized fragment separately |
| [z.AsyncChannelMessageBatched_Interface](z.AsyncChannelMessageBatched_Interface.md) | Shared insert interface batching serialized fragments by channel |
| [z.v_AsyncChannelScripts](z.v_AsyncChannelScripts.md) | Generated scripts, existing definitions and deployment/drift flags |
| [z.AsyncChannelSenderQueue](z.AsyncChannelSenderQueue.md) | Shared sender reply queue |

## Shared Service Broker objects

Each Broker object has its own page. The filenames below use dots in place of the slashes in their exact Broker names.

| Object | Responsibility |
| --- | --- |
| [/SchemaZ/AsyncChannel/Message](SchemaZ.AsyncChannel.Message.md) | Application payload message type without Broker content validation |
| [/SchemaZ/AsyncChannel/Contract](SchemaZ.AsyncChannel.Contract.md) | Allows application messages from the conversation initiator |
| [/SchemaZ/AsyncChannel/Sender](SchemaZ.AsyncChannel.Sender.md) | Shared initiator service bound to the sender reply queue |

The [sender queue](z.AsyncChannelSenderQueue.md) page also documents its activation binding. Each object page links to its SQL definition; per-channel generated objects and Demo objects are described by the generator and demo-creator pages rather than treated as installed framework objects.

See [usage](../usage.md) for application ownership and generation, and [architecture](../architecture.md) for transactional behavior and limits.
