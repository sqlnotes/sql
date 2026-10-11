# Async

[System documentation](../../docs/readme.md)

Provide Service Broker sender infrastructure and configuration/conversation tables for asynchronous integrations.

## Start here

- [Usage and examples](usage.md)
- [Architecture and dependencies](architecture.md)
- [Object reference](reference/readme.md)
- [Troubleshooting and current limitations](troubleshooting.md)

## Operational scope

This is infrastructure rather than a complete work-dispatch API. NumberOfInternalWorkers and IsActive are stored configuration values; this module does not implement their orchestration.

## Prerequisites

Service Broker must be available and enabled in the database for message delivery. Configuration rows must reference an existing view whose object name begins v_Async. The module does not create application-specific interface views, payload receivers, or submission procedures.
