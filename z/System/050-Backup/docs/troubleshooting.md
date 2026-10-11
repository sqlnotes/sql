# Backup troubleshooting

[Subsystem](readme.md) | [Object reference](reference/readme.md)

## Diagnose current behavior

Unknown or ineligible database names can lead to No databases to be backup rather than an error. Offline databases and database snapshots are not explicitly excluded by the selection query and can fail at native BACKUP execution. A null backup folder falls back to InstanceDefaultBackupPath, which may be unavailable on some target versions. Filesystem permissions belong to the SQL Server service account. The snapshot procedure stores physical_name in sysname (128 characters) and does not escape single quotes in generated filenames; long or quoted paths can fail.

## Permission and partial-operation failures

Uses sys.databases, sys.master_files, msdb backup history, filesystem extended procedures, and native backup/create database commands. Requires server-local or UNC storage accessible to the SQL Server service account.

Read the relevant callable reference before retrying a failed write. Some procedures roll back any open transaction, including a caller's transaction; others leave earlier operations committed. Native server resources and filesystem actions do not share a single database rollback boundary. Catalog/DMV access is evaluated on the deployed server and depends on SQL Server version and caller context.

## Verification limits

These pages describe source behavior. A successful installation or module compilation does not demonstrate successful mail delivery, backup restoration, SQL Agent execution, trace workload collection, security migration, or application-specific Broker delivery.
