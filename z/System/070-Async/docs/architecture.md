# Async architecture

[Subsystem](readme.md) | [Object index](reference/readme.md)

## Dependencies and installation

Service Broker must be available and enabled in the database for message delivery. Configuration rows must reference an existing view whose object name begins v_Async. The module does not create application-specific interface views, payload receivers, or submission procedures.

The numbered folder installs in System's alphabetical child order. Shared System modules run before feature children; System post scripts run after all children. See [System documentation](../../docs/readme.md) for deployment and orchestration. Baseline tables use existence guards; they do not reconcile an existing table schema. Module definitions use create or alter.

## Data and control flow

Baseline creates `z.AsyncConfiguration` and `z.AsyncConversation`. The Broker module creates two message types, one log contract, `z.AsyncSender`, and service `[z.Async.sender]`; it defines `z.usp_AsyncSenderActivator` through dynamic SQL before guarded queue creation. Activation waits for one response. For EndDialog, it ends the endpoint and deletes the conversation tracking row by `PayloadHandle`. The module contains no payload sender/receiver or code that inserts conversation rows, and it does not enable Broker in the database.

This is infrastructure rather than a complete work-dispatch API. NumberOfInternalWorkers and IsActive are stored configuration values; this module does not implement their orchestration.

Each callable reference describes writes, generated SQL, transaction boundaries, results and inputs. Supporting references describe keys, payloads and units. Procedures do not supply a blanket permission grant or one transaction around an entire administrative workflow.

## Integration constraints

If messages do not arrive, inspect database Broker status, sys.transmission_queue, endpoints, and queue activation state. The activator only handles EndDialog. Other messages, including Broker Error messages, are received without explicit handling or endpoint cleanup. RECEIVE, END CONVERSATION, and conversation-row DELETE are not wrapped in an explicit transaction; a later failure cannot atomically undo the receive. Reinstallation guards queue/service creation and does not reconcile existing queue activation settings.
