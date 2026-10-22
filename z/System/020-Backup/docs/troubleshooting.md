# Backup troubleshooting

[Subsystem](readme.md) | [Object reference](reference/readme.md)

## Diagnose current behavior

Unknown or ineligible database names can lead to No databases to be backup rather than an error. Offline databases and database snapshots are not explicitly excluded by the selection query and can fail at native BACKUP execution. A null backup folder falls back to InstanceDefaultBackupPath, which may be unavailable on some target versions. Filesystem permissions belong to the SQL Server service account. The snapshot procedure stores physical_name in sysname (128 characters) and does not escape single quotes in generated filenames; long or quoted paths can fail.

## Permission and partial-operation failures

Uses sys.databases, sys.master_files, msdb backup history, filesystem extended procedures, and native backup/create database commands. Requires server-local or UNC storage accessible to the SQL Server service account.

Default backup retention uses actual directory contents and the six-digit filename convention. Unrecognized names are preserved; use `UseBackupHeader = 1` for legacy or irregular names. No recognized full anchor at or before the cutoff means no deletion. Header mode also skips cleanup for unreadable/unsupported media or missing retained differential bases. Inspect the cleanup helper's preview before changing files. `msdb` history remains a reporting dependency only. On Linux, network storage must be mounted and accessible through an absolute filesystem path.

Read the relevant callable reference before retrying a failed write. Some procedures roll back any open transaction, including a caller's transaction; others leave earlier operations committed. Native server resources and filesystem actions do not share a single database rollback boundary. Catalog/DMV access is evaluated on the deployed server and depends on SQL Server version and caller context.

## Verification limits

Parallel workers must call the same coordination database. A settings conflict means an active session for that database set has different effective options; use matching settings or wait for it to exit. Inactive unfinished runs can resume with corrected options. Metadata validation failures require inspecting the reserved `z.Backup.Work.*` properties. Do not reset active assignments manually. If cancellation leaves workers waiting, close the canceled worker's dedicated connection to release its session locks. Completion records backup success before cleanup, so a cleanup error alone does not trigger another backup in the active batch.

These pages describe source behavior. A successful installation or module compilation does not demonstrate successful mail delivery, backup restoration, SQL Agent execution, trace workload collection, security migration, or application-specific Broker delivery.
