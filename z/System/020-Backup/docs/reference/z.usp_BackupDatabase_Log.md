# z.usp_BackupDatabase_Log

[Backup](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_BackupDatabase_Log.sql)

## Purpose and behavior

Call z.usp_BackupDatabase for AllDatabases, Log, compression enabled, no extra options, and the fixed path shown in source.

## Parameters and defaults

None.

These are the source-declared types and defaults.

## Results, permissions, and limits

No parameters or defined result set. Inherits backup permissions, file creation, and error behavior; SIMPLE databases are skipped.

## Dependencies

Direct SQL object dependencies: `z.usp_BackupDatabase`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
