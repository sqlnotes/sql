# Using AsyncChannel

[AsyncChannel](readme.md)

## Build and run the demo

[`z.usp_CreateDemoAsyncChannel`](../modules/1070%20Examples/z.usp_CreateDemoAsyncChannel.sql) demonstrates channel construction. Its leading SQL comments contain the complete usage sequence. Installation defines the procedure; invoke it explicitly in a database where Service Broker is enabled. Choose unused channel and pool IDs. The procedure rejects existing Demo registrations or objects instead of overwriting them.

```sql
exec z.usp_CreateDemoAsyncChannel @AsyncChannelID = 0, @ActivatorPoolID = 0;
go
insert into z.AsyncChannel_Demo_Interface (RecordID, Description, Date)
	values (1, N'First message', '2026-10-30T12:00:00'),
		   (2, N'Second message', '2026-10-30T12:00:01');
exec z.usp_AsyncChannel_Demo_Activator;
select RecordID, Description, Date from z.AsyncChannel_Demo order by RecordID;
```

The creator builds a pool, destination table `z.AsyncChannel_Demo`, authored interface `z.AsyncChannel_Demo_Interface`, and a Manual channel registration. It creates the interface before invoking the generator so column metadata is available. After generation supplies the codecs and processing scaffold, it replaces that new scaffold with `z.usp_AsyncChannel_Demo_Process`, which decodes payload rows into the destination table. Manual activation makes the send/receive steps visible; the creator sends no sample data itself.

Use the same sequence for an application channel: define the interface, register settings, generate infrastructure, and implement processing. The demo is separate from the generic framework objects and is created only on request. Channel removal preserves the authored view, processor and destination table; its pool is also retained. The SQL header describes cleanup ownership.

## Configure application channels

Applications register channels in `z.AsyncChannel`; no registration is seeded. Choose an explicit ID and conventional identifier name. Set `ProcessingProcedure` to a schema-qualified procedure name. Generated channel objects live in that schema; create the schema separately if required. The registry requires `ActivatorPoolID`; use an explicitly configured pool, or an ID with no pool row for unbounded processing. There is no foreign key enforcing membership. Configured pools use the shared semaphore helpers with Session ownership; TimeoutSeconds is -1 for indefinite waiting or a positive finite wait, capped at 2147483647 milliseconds after conversion.

Before generating, author the expected interface view: `<schema>.AsyncChannel_<Name>_Interface`. Its column names, order and types define serializer inputs and deserializer outputs. Avoid reserved enqueue parameter names `ConversationHandle`, `Payload` and `Attempt`, and use conventional identifier characters. Supply an application processing procedure with one `z.AsyncChannelMessage readonly` parameter. Generated stubs are scaffolding, not application processing.

Inspect the computed names, `IsValid` and `InvalidReason` in `z.v_AsyncChannel`. Inspect `GeneratedScript`, `ExistingScript`, `IsSameScript` and `NeedDeployment` in `z.v_AsyncChannelScripts`, ordered by `Ordinal`, before invoking `z.usp_AsyncChannelDeploy` with the channel ID. The drift indicator is separate from `NeedDeployment`; existing module text is not automatically replaced. `@ForceDeployment = 1` regenerates framework-managed channel modules while preserving existing Interface, Processing, Queue and Service objects.

Send structured rows by inserting into the channel interface or calling its generated `<schema>.usp_AsyncChannel_<Name>_Enqueue`. For already serialized fragments, call `z.usp_AsyncChannelSend`, or insert `(AsyncChannelID, DataSequence, Data)` into either shared framework interface. The batched interface joins fragments in sequence and chunks by `MaxRowsPerMessage`; the other interface sends one fragment per row. Supply JSON fragments without enclosing the complete batch in an array: the generated deserializer supplies the surrounding array for a batch fragment.

For `ActivationType = 'Auto'`, generation binds the channel activator to its queue. For `Manual`, the binding is disabled and the application invokes the generated activator explicitly. The processor receives message rows; decode only payload rows using the generated deserializer, and handle timer wakeups using `MessageTypeID` and the session-context timer type. `z.usp_AsyncChannelForward` forwards payload rows to a comma-separated list of destination channel IDs, optionally batching them.

Use `z.usp_AsyncChannelSetTimer` with a live conversation handle and a positive timeout. `z.fn_AsyncChannelCurrentTimer` returns remaining committed timer seconds, or NULL when no pending timer is visible. Rearming replaces the pending timer; the wrapper has no cancel operation.

Inspect `z.AsyncChannelLog`, `z.v_AsyncChannelActivatorPool` and the native queue/conversation catalogs for operation. Flush session-buffered logs with `z.usp_AsyncChannelLogFlush` after the caller transaction ends. Review [limitations](architecture.md) before using generation, manual activation, forced removal or caller-owned transactions.
