# Backup object index

[Subsystem](../readme.md) | [System](../../../docs/readme.md)

Exact SQL identifiers link to behavior and source. Native system dependencies are described in [architecture](../architecture.md).

| Object | Documentation | Definition |
| --- | --- | --- |
| `z.usp_BackupDatabase_Full` | [Reference](z.usp_BackupDatabase_Full.md) | [SQL](../../modules/1070%20Procedures/z.usp_BackupDatabase_Full.sql) |
| `z.usp_BackupDatabase_Log` | [Reference](z.usp_BackupDatabase_Log.md) | [SQL](../../modules/1070%20Procedures/z.usp_BackupDatabase_Log.sql) |
| `z.usp_BackupDatabasesParallel` | [Reference](z.usp_BackupDatabasesParallel.md) | [SQL](../../modules/1070%20Procedures/z.usp_BackupDatabasesParallel.sql) |
| `z.usp_BackupDatabase` | [Reference](z.usp_BackupDatabase.md) | [SQL](../../modules/1070%20Procedures/z.usp_BackupDatabase.sql) |
| `z.usp_RestoreDatabase` | [Reference](z.usp_RestoreDatabase.md) | [SQL](../../modules/1070%20Procedures/z.usp_RestoreDatabase.sql) |
| `z.usp_RestoreDatabaseTarget` | [Implementation helper](z.usp_RestoreDatabase.md) | [SQL](../../modules/1070%20Procedures/z.usp_RestoreDatabaseTarget.sql) |
| `z.usp_RestoreDatabaseExecute` | [Implementation helper](z.usp_RestoreDatabase.md) | [SQL](../../modules/1070%20Procedures/z.usp_RestoreDatabaseExecute.sql) |
| `z.usp_CleanupDatabaseBackups` | [Reference](z.usp_CleanupDatabaseBackups.md) | [SQL](../../modules/1070%20Procedures/z.usp_CleanupDatabaseBackups.sql) |
| `z.usp_CreateDatabaseSnapshot` | [Reference](z.usp_CreateDatabaseSnapshot.md) | [SQL](../../modules/1070%20Procedures/z.usp_CreateDatabaseSnapshot.sql) |
| `z.v_BackupRestore` | [Reference](supporting-objects.md#zv_backuprestore) | [SQL](../../modules/1020%20Views/z.v_BackupRestore.sql) |
| `z.v_BackupHistory` | [Reference](backup-restore-history.md#zv_backuphistory) | [SQL](../../modules/1020%20Views/z.v_BackupHistory.sql) |
| `z.v_RestoreHistory` | [Reference](backup-restore-history.md#zv_restorehistory) | [SQL](../../modules/1020%20Views/z.v_RestoreHistory.sql) |
| `z.v_BackupRestoreRequests` | [Reference](backup-restore-history.md#zv_backuprestorerequests) | [SQL](../../modules/1020%20Views/z.v_BackupRestoreRequests.sql) |
| `z.usp_CreateS3BackupCredential` | [Reference](z.usp_CreateS3BackupCredential.md) | [SQL](../../modules/1070%20Procedures/z.usp_CreateS3BackupCredential.sql) |
| `z.usp_ReadBackupHeader` | [Reference](z.usp_ReadBackupHeader.md) | [SQL](../../modules/1070%20Procedures/z.usp_ReadBackupHeader.sql) |
| `z.usp_ReadBackupFileList` | [Reference](z.usp_ReadBackupFileList.md) | [SQL](../../modules/1070%20Procedures/z.usp_ReadBackupFileList.sql) |
| `z.fn_DecodeBackupHeader` | [Reference](z.fn_DecodeBackupHeader.md) | [SQL](../../modules/1010%20Functions/z.fn_DecodeBackupHeader.sql) |
| `z.fn_DecodeBackupFileList` | [Reference](z.fn_DecodeBackupFileList.md) | [SQL](../../modules/1010%20Functions/z.fn_DecodeBackupFileList.sql) |

| `z.fn_DecodeBackupFileName` | [Reference](z.fn_DecodeBackupFileName.md) | [SQL](../../modules/1010%20Functions/z.fn_DecodeBackupFileName.sql) |
