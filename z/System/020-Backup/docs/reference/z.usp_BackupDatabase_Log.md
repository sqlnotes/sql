# z.usp_BackupDatabase_Log

[Backup](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_BackupDatabase_Log.sql)

## Purpose and behavior

Takes compressed transaction-log backups through [z.usp_BackupDatabase](z.usp_BackupDatabase.md), skipping databases in SIMPLE recovery. This parameterless scheduling shortcut uses `AllDatabases` and the fixed destination in its source, with no extra backup options. Review the destination before use; call the main procedure when you need different settings.

## Parameters and defaults

None.

## Results, permissions, and limits

No parameters or defined result set. The main procedure takes a regular full
backup before a log backup when the log chain needs initialization. It skips
databases in SIMPLE recovery. Backup permissions, file creation, and error
behavior follow the main procedure.

## Dependencies

Direct SQL object dependencies: `z.usp_BackupDatabase`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
