# z.usp_AsyncChannelSetTimer

[AsyncChannel](../readme.md) | [Reference](readme.md) | [Source](../../modules/1040%20Procedures/z.usp_AsyncChannelSetTimer.sql)

## Purpose and behavior

Schedules a timer message on an open Service Broker conversation in the current database. Use a receiving endpoint handle from a processing batch to wake that channel's processor later, even when no new payload arrives. The message goes to the queue owning the supplied endpoint; a sender-side handle therefore wakes the sender queue instead.

A conversation endpoint has one pending timer. Setting it again replaces that timer. Expiry queues a DialogTimer message rather than calling the processor directly.

## Parameters and defaults

```text
@ConversationHandle uniqueidentifier
@TimeoutSeconds int
```

Both are required. Reject NULL or less-than-one timeouts with error 50000. Reject a NULL/unknown endpoint or an endpoint outside states `SO`, `SI` and `CO` with error 50000. Native timer errors can also propagate.

## Results and side effects

No result set or explicit return-code contract. Rearming replaces the existing pending timer. Ending the conversation removes its timer; this wrapper has no cancel operation. To wake a channel's processor, use a receiving endpoint handle from that processor's message table. A sender-side handle targets the sender queue instead.

The generated channel activator identifies DialogTimer rows as non-payload (`IsPayload = 0`) and invokes the processor for them. The processor should identify timer messages before decoding JSON; the activator caches their native type ID in `AsyncChannel-TimerTypeID` session context.

## Transactions, permissions, and limits

The procedure sets `xact_abort on` and starts no transaction. Timer changes take effect on commit; rollback retains the prior timer state. Requires applicable conversation/timer permissions. A timer schedules a message, not a hard deadline for execution or a guarantee that a processor is available immediately.

## Dependencies

Native conversation endpoints and the channel's generated activator/processing contract. `z.fn_AsyncChannelCurrentTimer` can inspect the remaining committed timer seconds.

See [architecture](../architecture.md) for message flow, ownership and operational limits.
