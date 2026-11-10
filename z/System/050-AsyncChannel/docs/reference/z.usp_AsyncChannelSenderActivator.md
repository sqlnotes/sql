# z.usp_AsyncChannelSenderActivator

[AsyncChannel](../readme.md) | [Reference](readme.md) | [Source](../../modules/1040%20Procedures/z.usp_AsyncChannelSenderActivator.sql)

## Purpose and behavior

Consume replies from the shared `z.AsyncChannelSenderQueue`. This is the sender-side control-message receiver; per-channel payload processing is performed by separately generated channel activators.

## Parameters and defaults

None.

## Results and side effects

No result set or explicit return-code contract. RECEIVE one message at a time with a 1,100 ms empty-queue timeout, ending the invocation when no message arrives. For Broker Error and EndDialog messages, end the local conversation, delete matching `z.AsyncChannelSession` rows, and write an Error or Info log. Attribution uses registry values resolved before deletion and may be NULL when none are found.

Other message types are received but have no further processing branch. The routine does not deserialize application rows or acquire an activator-pool slot.

## Transactions, permissions, and limits

No explicit transaction or catch block is supplied. RECEIVE, endpoint cleanup, registry deletion and logging are not wrapped by this procedure in one atomic unit; applicable caller transactions still govern their effects. Errors can propagate. The installation binds this procedure to the sender queue with one automatic reader executing as owner. Direct invocation requires applicable queue RECEIVE, dialog and registry/log permissions.

## Dependencies

`z.AsyncChannelSenderQueue`, `z.AsyncChannelSession`, and `z.usp_AsyncChannelLog`.

See [architecture](../architecture.md) for message flow, ownership and operational limits.
