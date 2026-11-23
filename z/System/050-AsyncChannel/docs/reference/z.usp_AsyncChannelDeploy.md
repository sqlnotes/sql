# z.usp_AsyncChannelDeploy

[AsyncChannel](../readme.md) | [Reference](readme.md) | [Source](../../modules/1040%20Procedures/z.usp_AsyncChannelDeploy.sql)

## Purpose and behavior

Creates the infrastructure needed by a registered application channel: message codecs, send entry points, queue/service and receiver activation. Register the channel and author its interface view first, then use this procedure to make that configuration usable.

By default it installs missing objects and required activation changes identified by `z.v_AsyncChannelScripts`. A difference between generated and installed SQL (`IsSameScript`) does not by itself replace an existing object. Review the generated scripts before choosing forced deployment.

## Parameters and defaults

```text
@AsyncChannelID int
@ForceDeployment bit = 0
```

`@ForceDeployment = 1` also selects framework-managed generated objects, while excluding existing Interface, Queue, Service and Processing objects from that forced selection. Missing objects can still be selected by `NeedDeployment`. Existing authored interface and processing definitions are preserved.

## Results and side effects

No defined result set or explicit return-code contract. Dynamic DDL creates missing per-channel infrastructure, codecs, interface trigger, Enqueue and activator procedures, and a processing scaffold if missing. Auto channels receive an activation binding; Manual channels have automatic activation disabled. An ID with no script rows performs no work.

## Transactions, permissions, and limits

The procedure sets `xact_abort on` but starts no transaction of its own. Outside a caller transaction, a later failure can leave earlier scripts installed. Requires permissions for the generated DDL and referenced schemas, types, Broker objects and activation context; no grants are supplied by this procedure.

Author the expected channel interface before calling: all scripts are prepared from the metadata available at the start, so a placeholder interface created during deployment does not refresh the already-prepared codecs. Inspect `z.v_AsyncChannel` and `z.v_AsyncChannelScripts` before deployment. Generated names/types must satisfy the limits in [architecture](../architecture.md).

## Example

For an already registered channel with an authored interface:

```sql
exec z.usp_AsyncChannelDeploy @AsyncChannelID = 100;
```

## Dependencies

`z.v_AsyncChannelScripts` and the objects referenced by its generated scripts.

See [architecture](../architecture.md) for message flow, ownership and operational limits.
