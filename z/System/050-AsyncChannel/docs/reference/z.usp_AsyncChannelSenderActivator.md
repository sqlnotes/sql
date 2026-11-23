# z.usp_AsyncChannelSenderActivator

[AsyncChannel](../readme.md) | [Reference](readme.md) | [Source](../../modules/1040%20Procedures/z.usp_AsyncChannelSenderActivator.sql)

## Purpose and behavior

Consume replies from the shared `z.AsyncChannelSenderQueue`. This is the sender-side control-message receiver; per-channel payload processing is performed by separately generated channel activators.

## Parameters and defaults

None.

## Results and side effects

No result set or explicit return-code contract. It processes replies one at a time and returns after a 1,100 ms wait finds no message. Broker Error and EndDialog notifications close the local conversation and remove its reusable-session registration, with an Error or Info diagnostic. Channel/session attribution can be NULL when no registration remains.

Other message types are received but have no further processing branch. The routine does not deserialize application rows or acquire an activator-pool slot.

## Transactions, permissions, and limits

No explicit transaction or catch block is supplied. RECEIVE, endpoint cleanup, registry deletion and logging are not wrapped by this procedure in one atomic unit; applicable caller transactions still govern their effects. Errors can propagate. The installation binds this procedure to the sender queue with one automatic reader executing as owner. Direct invocation requires applicable queue RECEIVE, dialog and registry/log permissions.

## Dependencies

`z.AsyncChannelSenderQueue`, `z.AsyncChannelSession`, and `z.usp_AsyncChannelLog`.

See [architecture](../architecture.md) for message flow, ownership and operational limits.
