# Monitoring

[System documentation](../../docs/readme.md)

Inspect current requests, persist diagnostic snapshots, collect selected system_health events, and report resource and storage usage.

## Start here

- [Usage and examples](usage.md)
- [Architecture and dependencies](architecture.md)
- [Object reference](reference/readme.md)
- [Troubleshooting and current limitations](troubleshooting.md)

## Operational scope

Snapshots capture requests at collection time, not a full session history. Query text, plans, login names, and client details can be sensitive. Database Mail configuration is an administrative operation that changes server settings and msdb; it is not a health-only check.

## Prerequisites

System supplies z.SeqGeneralID and PS_SchemaZPartitionGeneric. Server DMVs, Extended Events, and msdb Database Mail supply external data. System orchestration can schedule collection through Jobs. [Trace](../../010-Trace/docs/readme.md) supplies the SQL Trace framework for monitoring presets and installs before Monitoring.
