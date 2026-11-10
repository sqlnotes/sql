# z.usp_AsyncChannelRemove

[AsyncChannel](../readme.md) | [Reference](readme.md) | [Source](../../modules/1040%20Procedures/z.usp_AsyncChannelRemove.sql)

## Purpose and behavior

Remove a registered channel's generated infrastructure and registration while preserving application-authored objects. Resolve names from `z.v_AsyncChannel`; an unknown channel ID is a no-op.

## Parameters and defaults

```text
@AsyncChannelID int
```

## Results and side effects

No defined result set or explicit return-code contract. Disable automatic activation on the target queue, forcibly clean up selected conversation endpoints with `END CONVERSATION ... WITH CLEANUP`, and delete the channel's `z.AsyncChannelSession` rows. Drop the generated interface trigger, Enqueue/activator procedures, serializer/deserializer functions, target service and queue, then delete the channel registration.

The authored interface view, application processing procedure, destination tables, activator-pool row and diagnostic logs are retained. Forced conversation cleanup discards outstanding work; removal is not a graceful drain or a complete framework uninstall.

## Transactions, permissions, and limits

The procedure sets `xact_abort on` but starts no transaction and has no catch handler. Outside a caller transaction, failure can leave partial removal. It disables activation but does not explicitly wait for existing readers or coordinate concurrent send/deploy activity. Review active work before invoking it.

Requires permissions to alter/drop the generated objects and forcibly clean up the relevant conversations under the applicable execution context. Dynamic generated names must remain compatible with the channel metadata.

## Dependencies

`z.v_AsyncChannel`, `z.AsyncChannelSession`, `z.AsyncChannel`, the channel's generated objects, and native Broker catalogs.

See [architecture](../architecture.md) for message flow, ownership and operational limits.
