# z.v_AsyncChannel

[AsyncChannel](../readme.md) | [Reference](readme.md) | [Source](../../modules/1020%20Views/z.v_AsyncChannel.sql)

## Purpose and output

Expands each [channel registration](z.AsyncChannel.md) into resolved object names, catalog identities, optional pool information and structural validation reasons. It reads metadata and performs no generation or writes.

The output includes all channel settings; ActivatorPoolName and ActivatorPoolMaxConcurrency; SchemaName; and the following object-name/catalog pairs:

| Name | Catalog identity |
| --- | --- |
| SourceInterface | SourceInterfaceObjectID |
| SourceInterfaceTrigger | SourceInterfaceTriggerObjectID |
| ActivatorProcedure | ActivatorProcedureObjectID |
| ProcessingProcedure | ProcessingProcedureObjectID |
| EnqueueProcedure | EnqueueProcedureObjectID |
| Serializer | SerializerObjectID |
| Deserializer | DeserializerObjectID |
| QueueName | QueueObjectID |
| ServiceName | ServiceExists |

SchemaName comes from the second PARSENAME part of ProcessingProcedure, defaulting to `z` when absent. Names follow `AsyncChannel_<Name>_Interface`, `TRI_AsyncChannel_<Name>_Interface`, `usp_AsyncChannel_<Name>_Activator`, `usp_AsyncChannel_<Name>_Enqueue`, `fn_AsyncChannelSerializer_<Name>`, `fn_AsyncChannelDeserializer_<Name>` and `AsyncChannelQueue_<Name>` in that schema. ServiceName is `/SchemaZ/AsyncChannel/<schema>/<Name>/Service`.

## Validation

IsValid is a bit equal to one when InvalidReason is NULL. InvalidReason combines detected problems with semicolons: disabled channel, missing schema or expected objects/service, reserved interface columns ConversationHandle/Payload/Attempt, mismatched serializer parameter or deserializer output signatures, serializer output other than a single Json column, deserializer input other than a single nvarchar(max), activator parameters, or a processor lacking exactly one parameter of type `z.AsyncChannelMessage`.

Type comparison uses [z.fn_AsyncChannelTypeDef](z.fn_AsyncChannelTypeDef.md). Optional pool details use a LEFT JOIN, so a missing pool does not remove the channel or itself make IsValid false.

## Permissions and limits

Catalog metadata visibility affects object lookup and signatures. This is a partial structural report, not proof that processing is correct, Service Broker is enabled, SQL is deployable, or type conversion is lossless. Missing generated objects can be expected before initial deployment. Read [z.v_AsyncChannelScripts](z.v_AsyncChannelScripts.md) and [architecture](../architecture.md) before executing generation.
