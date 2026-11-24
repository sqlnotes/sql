# Supporting objects and utilities

[Subsystem](../readme.md) | [Object index](readme.md)

## Access and behavior

Use these read-only views to inspect backup and restore records already retained by the local SQL Server instance. They report history rather than opening backup files. The caller needs access to the underlying `msdb` history; granting access to a wrapper does not grant additional system privileges.

## z.v_BackupRestore

[Source](../../modules/1020%20Views/z.v_BackupRestore.sql)

Combines backup, media and restore history so you can see where a backup was written and where it was restored. Results include database/server names, backup type, dates, duration, media location, backup/compressed sizes in MB, LSNs and recovery details. A backup can appear more than once when it has several media files or restore records. The existing `FirstLNS` and `LastLNS` aliases are retained. A recorded path does not prove that its file still exists or can be restored.
