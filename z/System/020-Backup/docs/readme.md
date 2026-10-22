# Backup

[System documentation](../../docs/readme.md)

Run full, differential, or transaction-log backups; report msdb backup/restore history; create database snapshots.

## Start here

- [Usage and examples](usage.md)
- [Architecture and dependencies](architecture.md)
- [Object reference](reference/readme.md)
- [Troubleshooting and current limitations](troubleshooting.md)

## Operational scope

After a successful backup, retention inventories the selected database's managed FULL, DIFF and LOG folders. Default cleanup uses the six-digit timestamp filename convention and preserves unrecognized names. Optional `UseBackupHeader = 1` uses backup headers for legacy or irregular filenames and dependency checks. `NULL` retention disables cleanup; zero and negative values are rejected. See [cleanup behavior](reference/z.usp_CleanupDatabaseBackups.md).

Windows destinations can use absolute local or UNC paths. Linux destinations use absolute filesystem paths, including mounted network shares. The parameterless Full/Log wrappers contain a fixed UNC destination; inspect them before use.

## Prerequisites

Uses sys.databases, sys.master_files, msdb backup history, filesystem extended procedures, and native backup/create database commands. Requires server-local or UNC storage accessible to the SQL Server service account.
