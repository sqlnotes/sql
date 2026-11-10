# z.usp_CreateDemoAsyncChannel

[AsyncChannel](../readme.md) | [Reference](readme.md) | [Source](../../modules/1070%20Examples/z.usp_CreateDemoAsyncChannel.sql)

## Purpose and behavior

Create an opt-in worked example of an AsyncChannel with fixed Demo object names, a dedicated one-slot pool and Manual activation. Installing this procedure only defines it; invocation creates the example and sends no data itself.

## Parameters and defaults

```text
@AsyncChannelID int = 0
@ActivatorPoolID int = 0
```

Choose unused explicit IDs. NULL IDs are rejected. Fixed Demo names allow only one such example per database even when IDs differ.

## Results and created objects

No result set or explicit return-code contract. Create `z.AsyncChannel_Demo` with RecordID, Description and Date; author `z.AsyncChannel_Demo_Interface`; register the pool and channel; call `z.usp_AsyncChannelDeploy`; and replace the newly created processing scaffold with `z.usp_AsyncChannel_Demo_Process`.

The processor deserializes payload rows, selects one row per RecordID and upserts the destination by RecordID. Generated objects include codecs, interface trigger, Enqueue procedure, target queue/service and channel activator. Settings include pool capacity 1/timeout 5 seconds, Readers 1, MaxRowsPerMessage 10, MaxMessagesPerReceive 100, idle limit 2 seconds and cooperative execution limit 5 seconds.

## Transactions, permissions, and limits

Reject ambient explicit or implicit transactions. Begin an owned transaction and obtain a Transaction-owned one-permit creation semaphore with a 10-second wait. Reject existing Demo registrations, requested IDs, known objects or target service rather than overwriting them. Commit on success; catch rolls back and rethrows.

Requires DDL/registry/Broker permissions for all created objects and the activation context. Enable database Service Broker separately before sending. Manual activation must be invoked after sends commit; delivery is asynchronous, so an empty receive may need another invocation.

## Example

Run in the intended database with unused IDs and outside explicit/implicit transactions:

```sql
exec z.usp_CreateDemoAsyncChannel @AsyncChannelID = 0, @ActivatorPoolID = 0;
go
insert into z.AsyncChannel_Demo_Interface (RecordID, Description, Date)
	values (1, N'First message', '2026-01-01T12:00:00');
exec z.usp_AsyncChannel_Demo_Activator;
select RecordID, Description, Date from z.AsyncChannel_Demo order by RecordID;
```

## Cleanup and dependencies

`z.usp_AsyncChannelRemove` removes the Demo channel and generated infrastructure with forced conversation cleanup. It preserves the authored interface, processing procedure, destination table and pool registration; review data and pool usage before removing those separately. Substitute the chosen channel ID when not using zero.

Dependencies include `z.usp_AcquireSemaphore`, `z.AsyncChannelActivatorPool`, `z.AsyncChannel`, `z.AsyncChannelMessage`, `z.usp_AsyncChannelDeploy`, and the generator's shared prerequisites. See [usage](../usage.md) for the construction sequence.

See [architecture](../architecture.md) for message flow, ownership and operational limits.
