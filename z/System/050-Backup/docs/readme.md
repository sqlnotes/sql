# Backup

[System documentation](../../docs/readme.md)

Run full, differential, or transaction-log backups; report msdb backup/restore history; create database snapshots.

## Start here

- [Usage and examples](usage.md)
- [Architecture and dependencies](architecture.md)
- [Object reference](reference/readme.md)
- [Troubleshooting and current limitations](troubleshooting.md)

## Operational scope

Backup execution can delete earlier backup files. The retention scan is based on msdb history and is not restricted to the requested backup folder. The parameterless Full/Log wrappers contain a fixed UNC destination; inspect them before use.

## Prerequisites

Uses sys.databases, sys.master_files, msdb backup history, filesystem extended procedures, and native backup/create database commands. Requires server-local or UNC storage accessible to the SQL Server service account.
