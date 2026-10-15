# System developer guide

System is the shared foundation of Schema Z: identifiers, strings/dates, catalog views, schema scripting, coordination and maintenance. All subsystems use the same SQL schema, `z`; folders separate deployment ownership.

## Start here

- [Install and update](../../docs/deploy.md)
- [Using shared utilities](usage.md)
- [Architecture and dependencies](architecture.md)
- [Object index and reference](reference/readme.md)
- [Troubleshooting and compatibility](troubleshooting.md)

## Subsystems

Installation visits these children sequentially in the alphabetical order shown. Children with the same numeric prefix share an installation dependency tier and do not require installation precedence among themselves; runtime calls can still cross subsystem boundaries. Each has its own developer guide and object reference.

| Subsystem | Purpose |
| --- | --- |
| [010-Jobs](../010-Jobs/docs/readme.md) | SQL Agent schedules and job management |
| [010-Partition](../010-Partition/docs/readme.md) | Boundaries, schemes and retention |
| [010-Security](../010-Security/docs/readme.md) | Login, user and permission utilities |
| [010-Trace](../010-Trace/docs/readme.md) | Definitions, storage, collection and lifecycle |
| [020-Backup](../020-Backup/docs/readme.md) | Backup/restore reporting and snapshots |
| [020-Monitoring](../020-Monitoring/docs/readme.md) | Sessions, resource/space views and System Health |
| [070-Async](../070-Async/docs/readme.md) | Service Broker configuration and conversation tracking |

## Compatibility and permissions

The minimum supported version is SQL Server 2019 (15.x). The shared index view and schema-copy output use `optimize_for_sequential_key`, supported from that version. See [current limitations](troubleshooting.md).

Administrative routines can modify more than `z` or the current database. The library does not grant a universal application role. Callers need permissions for the catalog queries, DDL, SQL Agent and server features they invoke. Examples assume an installed library in the selected database. They describe current source behavior and are illustrative, not a complete compatibility/concurrency test.
