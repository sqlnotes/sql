# z.v_AsyncChannelScripts

[AsyncChannel](../readme.md) | [Reference](readme.md) | [Source](../../modules/1030%20Script%20Views/z.v_AsyncChannelScripts.sql)

## Purpose and output

Produces per-channel SQL templates alongside installed definitions and deployment indicators. Reading the view generates text only; [z.usp_AsyncChannelDeploy](z.usp_AsyncChannelDeploy.md) executes selected scripts separately.

| Column | Meaning |
| --- | --- |
| AsyncChannelID, Name | Channel identity |
| Ordinal | Required script execution order |
| ObjectType | Template category shown below |
| ObjectName | Resolved target object or service name |
| GeneratedScript | SQL generated from configuration and interface metadata |
| ExistingScript | Installed module definition, or queue/service/binding text reconstructed from catalogs |
| IsSameScript | NULL when ExistingScript is absent; otherwise bit comparison with generated text |
| NeedDeployment | Bit indicating missing infrastructure or a required activation-binding change |

## Template order

| Ordinal | ObjectType | Responsibility |
| --- | --- | --- |
| 1 | Interface | Empty interface scaffold if missing |
| 5 | Queue | Target queue with poison handling off |
| 6 | Service | Target service using the shared contract |
| 20 | Serializer | Typed values to JSON |
| 30 | Deserializer | JSON fragments to typed rows |
| 40 | Trigger | Interface INSERT serialization and sending |
| 50 | Enqueue | Parameter-based serialization and sending |
| 70 | Processing | Application processor scaffold if missing |
| 80 | Activator | Receive, pool admission, processing and transaction loop |
| 90 | ActivatorBinding | Enable Auto activation with configured Readers, or disable it for Manual |

## Deployment versus drift

NeedDeployment tests service existence, activation state/procedure/reader settings, or object existence for other categories. It does not generally request replacement just because installed SQL differs. IsSameScript is a separate text-drift indicator and accepts SQL Server's stored `create   ` normalization of `create or alter`. Missing metadata can make installed definitions unavailable.

Forced deployment selects existing generated modules and activation binding, but preserves existing Interface, Queue, Service and Processing objects. Missing objects in those categories can still be created normally. Reading this view does not apply force behavior or alter objects.

## Dependencies and limits

Depends on [z.v_AsyncChannel](z.v_AsyncChannel.md), [z.fn_AsyncChannelColumns](z.fn_AsyncChannelColumns.md), native object/service catalogs and framework helpers referenced by its templates. Metadata access and later CREATE/ALTER/EXECUTE permissions are distinct requirements.

Author the interface before generation: the deploy procedure materializes a static script cursor, so a placeholder interface created during that call does not refresh its already-built codec templates. Conventional names and supported built-in types are assumed. Review GeneratedScript explicitly; IsValid, drift equality and NeedDeployment do not establish safe or correct application behavior. See [architecture](../architecture.md) for transaction, retry and nested-pool restrictions.
