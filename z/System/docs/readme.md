# System developer guide

System provides the helpers used throughout Schema Z and available to your own SQL: inspect table definitions, work with text and dates, generate scripts, store settings and coordinate concurrent work. Its objects are installed in schema `z` of the database you choose.

The feature modules below build on these helpers to manage jobs, partitions, backups, diagnostics and asynchronous processing. Start with the usage examples for a task, then use the object reference for parameter meanings and returned values.

## Start here

- [Install and update](../../docs/deploy.md)
- [Using shared utilities](usage.md)
- [Architecture and dependencies](architecture.md)
- [Object index and reference](reference/readme.md)
- [Troubleshooting and compatibility](troubleshooting.md)

## Subsystems

Choose the module for the work you want to do. The numbered folders also determine installation order; see [architecture and dependencies](architecture.md) when changing or deploying the library.

| Subsystem | Purpose |
| --- | --- |
| [010-Jobs](../010-Jobs/docs/readme.md) | SQL Agent schedules and job management |
| [010-Partition](../010-Partition/docs/readme.md) | Boundaries, schemes and retention |
| [010-Security](../010-Security/docs/readme.md) | Login, user and permission utilities |
| [010-Trace](../010-Trace/docs/readme.md) | Trace framework, configuration, collection and lifecycle |
| [012-TaskQueue](../012-TaskQueue/docs/readme.md) | Generic task batches, execution levels, workers and recovery |
| [020-Backup](../020-Backup/docs/readme.md) | Sequential and parallel backups, restore planning, history, retention and snapshots |
| [020-Monitoring](../020-Monitoring/docs/readme.md) | Sessions, diagnostic trace presets, resource/space views and System Health |
| [020-Sync](../020-Sync/docs/readme.md) | Configured initial and incremental data transfers, filters, publishers and progress |
| [050-AsyncChannel](../050-AsyncChannel/docs/readme.md) | Asynchronous data delivery, generated codecs, activation and processing pools |

## Compatibility and permissions

The minimum supported version is SQL Server 2019 (15.x). The shared index view and schema-copy output use `optimize_for_sequential_key`, supported from that version. See [current limitations](troubleshooting.md).

Administrative routines can modify more than `z` or the current database. The library does not grant a universal application role. Callers need permissions for the catalog queries, DDL, SQL Agent and server features they invoke. Run examples from the database where you installed Schema Z.
