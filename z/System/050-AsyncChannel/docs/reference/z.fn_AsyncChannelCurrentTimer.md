# z.fn_AsyncChannelCurrentTimer

[AsyncChannel](../readme.md) | [Reference](readme.md) | [Source](../../modules/1010%20Functions/z.fn_AsyncChannelCurrentTimer.sql)

## Purpose and parameters

Returns remaining seconds on a visible committed conversation timer in the current database.

```text
@ConversationHandle uniqueidentifier
```

No default is declared. Returns `int`; NULL input returns NULL without executing the body.

## Results and limits

Reads `sys.conversation_endpoints` for states `SO`, `SI` or `CO`, comparing `dialog_timer` with `sysutcdatetime()`. Returns NULL when no matching open endpoint exists or the pending timer sentinel is 1900-01-01. That sentinel is also used after the DialogTimer message has been queued. An overdue timer not yet queued returns zero rather than a negative value.

The seconds value uses DATEDIFF boundaries; it is not a precise fractional countdown. Only committed timers visible through the endpoint catalog are reflected. A NULL result does not distinguish an unknown/closed conversation from a timer that is absent or already queued.

## Dependencies and side effects

Read-only catalog access, subject to endpoint metadata visibility. It does not arm, replace or cancel a timer. Use [z.usp_AsyncChannelSetTimer](z.usp_AsyncChannelSetTimer.md) to arm one and review [architecture](../architecture.md) for transaction timing.
