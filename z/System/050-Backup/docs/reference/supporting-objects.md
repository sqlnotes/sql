# Supporting objects and utilities

[Subsystem](../readme.md) | [Object index](readme.md)

## Access and behavior

Views/functions here read data without modifying it. Table access requires the corresponding select or write permission. Server/database catalog and DMV visibility can hide rows or reject access; permission on a wrapper alone does not guarantee access through every underlying system object. Definitions do not grant caller privileges. Units and interpretation below follow the expressions in source.

## z.v_BackupRestore

[Source](../../modules/1020%20Views/z.v_BackupRestore.sql)

msdb backupset/media/restorehistory joins -> server/database/type/device/software/recovery/compatibility/collation, dates/duration/location, backup/compressed MB, LSNs, password flag and restore details. Can return multiple rows per backup for media stripes and restore operations. Preserves source aliases FirstLNS/LastLNS. It reports recorded history, not current file existence or recoverability.
