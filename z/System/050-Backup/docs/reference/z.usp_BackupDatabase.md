# z.usp_BackupDatabase

[Backup](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_BackupDatabase.sql)

## Purpose and behavior

1. Select databases from AllDatabases, UserDatabases, SystemDatabases, or a comma-separated list. Exclude tempdb and five error/recovery states; skip SIMPLE recovery for log backups.
2. Resolve the destination and process databases in ascending data-file size.
3. Create instance/database/backup-type subfolders if `sys.dm_os_file_exists` does not identify an existing directory. Filesystem access failures propagate from native operations.
4. Print and execute native backup SQL. `OtherBackupOptions` is appended as trusted SQL.
5. After each successful backup, scan msdb history for older physical files for that database and backup type, then delete matching existing files older than `abs(RetentionHours)`.

## Cleanup scope

Retention includes files outside `BackupFolder`: no folder-prefix predicate restricts deletion. This removes physical files; it does not prune msdb history or verify the remaining restore chain. Choosing a new destination does not isolate cleanup to that destination.

## Transactions and failures

The procedure starts no explicit transaction. Its catch rolls back any open transaction, including a caller's transaction, and rethrows. Previously completed backups and filesystem actions remain. A failure can stop processing before later databases are backed up.

## Parameters and defaults

```text
@Databases nvarchar(max) = 'AllDatabases', @BackupType nvarchar(50) = 'Full', @BackupFolder nvarchar(max) = null, @BackupCompression bit = 1,@OtherBackupOptions nvarchar(max) = null,@RetentionHours int = 30
```

These are the source-declared types and defaults.

## Results, permissions, and limits

No defined result set; prints commands and native backup messages. Requires backup rights in every target and access to filesystem procedures/history. Compression null reads the server default. Retention null does not match dated cleanup rows. Never use this as a dry-run generator.

## Dependencies

Native dependencies: `master.sys.xp_create_subdir`, `msdb.dbo.backupmediafamily`, `msdb.dbo.backupmediaset`, `msdb.dbo.backupset`, `sys.configurations`, `sys.databases`, `sys.dm_os_file_exists`, `sys.master_files`.

Native BACKUP plus master.sys.xp_create_subdir and master..xp_delete_file are executed; filesystem changes are part of the operation.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
