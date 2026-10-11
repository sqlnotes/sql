# Async troubleshooting

[Subsystem](readme.md) | [Object reference](reference/readme.md)

## Diagnose current behavior

If messages do not arrive, inspect database Broker status, sys.transmission_queue, endpoints, and queue activation state. The activator only handles EndDialog. Other messages, including Broker Error messages, are received without explicit handling or endpoint cleanup. RECEIVE, END CONVERSATION, and conversation-row DELETE are not wrapped in an explicit transaction; a later failure cannot atomically undo the receive. Reinstallation guards queue/service creation and does not reconcile existing queue activation settings.

## Permission and partial-operation failures

Service Broker must be available and enabled in the database for message delivery. Configuration rows must reference an existing view whose object name begins v_Async. The module does not create application-specific interface views, payload receivers, or submission procedures.

Read the relevant callable reference before retrying a failed write. Some procedures roll back any open transaction, including a caller's transaction; others leave earlier operations committed. Native server resources and filesystem actions do not share a single database rollback boundary. Catalog/DMV access is evaluated on the deployed server and depends on SQL Server version and caller context.

## Verification limits

These pages describe source behavior. A successful installation or module compilation does not demonstrate successful mail delivery, backup restoration, SQL Agent execution, trace workload collection, security migration, or application-specific Broker delivery.
