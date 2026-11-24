# z.usp_BackupDatabase_Full

[Backup](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_BackupDatabase_Full.sql)

## Purpose and behavior

Takes compressed full backups of the databases selected by `AllDatabases`, using [z.usp_BackupDatabase](z.usp_BackupDatabase.md). This is a parameterless scheduling shortcut with a fixed destination in its source. Review that destination before using it; call the main procedure when you need to choose a folder or database list. Progress is reported with `stats = 1`.

## Parameters and defaults

None.

## Results, permissions, and limits

No parameters or defined result set. Inherits backup permissions, file creation, and error behavior.

## Dependencies

Direct SQL object dependencies: `z.usp_BackupDatabase`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
