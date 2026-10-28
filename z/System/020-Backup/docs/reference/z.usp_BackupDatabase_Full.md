# z.usp_BackupDatabase_Full

[Backup](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_BackupDatabase_Full.sql)

## Purpose and behavior

Call z.usp_BackupDatabase for AllDatabases, FULL, compression enabled, stats = 1, and the fixed path shown in source.

## Parameters and defaults

None.

These are the source-declared types and defaults.

## Results, permissions, and limits

No parameters or defined result set. Inherits backup permissions, file creation, and error behavior.

## Dependencies

Direct SQL object dependencies: `z.usp_BackupDatabase`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
