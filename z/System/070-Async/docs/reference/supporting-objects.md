# Supporting objects and utilities

[Subsystem](../readme.md) | [Object index](readme.md)

## Access and behavior

Views/functions here read data without modifying it. Table access requires the corresponding select or write permission. Server/database catalog and DMV visibility can hide rows or reject access; permission on a wrapper alone does not guarantee access through every underlying system object. Definitions do not grant caller privileges. Units and interpretation below follow the expressions in source.

## z.AsyncConfiguration

[Source](../../baseline/1010%20Objects/z.AsyncConfiguration.sql)

ConfigurationID int identity primary key; unique Name nvarchar(128), nullable Description nvarchar(1000), unique InterfaceViewName nvarchar(200), NumberOfInternalWorkers int default 1, IsActive bit default 0, RowVersion rowversion with index. Check requires an existing view object whose name starts v_Async. No positive worker-count constraint.

Column definitions (including source defaults):

```text
ConfigurationID int not null identity(1,1),
Name nvarchar(128) not null,
Description nvarchar(1000),
InterfaceViewName nvarchar(200) not null,
NumberOfInternalWorkers int not null constraint DF_z_AsyncConfiguration_NumberOfInternalWorkers default(1),
IsActive bit not null constraint DF_z_AsyncConfiguration_IsActive default(0),
RowVersion rowversion not null,
```



## z.AsyncConversation

[Source](../../baseline/1010%20Objects/z.AsyncConversation.sql)

Key (InitiatorSessionID smallint, ConfigurationID int); PayloadHandle and PayloadConversation uniqueidentifier have unique indexes, ConfigurationID an index. No FK to AsyncConfiguration and no row insertion API here. EndDialog activator deletes by PayloadHandle.

Column definitions (including source defaults):

```text
InitiatorSessionID smallint not null,
ConfigurationID int not null,
PayloadHandle uniqueidentifier not null,
PayloadConversation uniqueidentifier not null,
```



## z.usp_AsyncSenderActivator

[Source](../../modules/1000%20ServiceBroker/ServiceBrokerConfiguration.sql) (defined inside dynamic SQL). No parameters or result set. Wait up to 1000ms for one message from z.AsyncSender; return if none. On EndDialog, end the received endpoint and delete matching z.AsyncConversation by PayloadHandle. Other messages are consumed without explicit action. No explicit transaction, catch, loop, or error-payload processing. Queue activation executes as owner; explicit execution requires receive/endpoint/delete permissions.

## z.AsyncSender

[Source](../../modules/1000%20ServiceBroker/ServiceBrokerConfiguration.sql). Broker queue created status on, retention off, poison-message handling on, activation on with z.usp_AsyncSenderActivator, max_queue_readers=10 and execute as owner. Native queue columns include conversation_handle, message_type_name, message_body; receiver code only reads handle/type. Creation is guarded; existing configuration is not updated.

## Broker message types, contract, and service

[Source](../../modules/1000%20ServiceBroker/ServiceBrokerConfiguration.sql). Message types [z.async.m-payload] and [z.async.m-log] both validation=none. Contract [z.async.c-log] permits [z.async.m-log] sent by initiator. Service [z.Async.sender] binds z.AsyncSender and that contract. No payload contract or receiver is created. Object names are Broker identifiers rather than schema-qualified procedure names.
