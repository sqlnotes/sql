# z.usp_CleanupBackupRestoreObjects

[Backup](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_CleanupBackupRestoreObjects.sql)

Removes leftover temporary executor procedures, per-target worker procedures, and idle temporary SQL Server Agent jobs left behind when a multi-threaded `z.usp_BackupDatabase` or future multi-threaded `z.usp_RestoreDatabase` run ends unexpectedly (for example, after a job stop, session kill, or client cancellation).

## Usage and prerequisites

Call the procedure from the database containing Schema Z outside any transaction with `IMPLICIT_TRANSACTIONS OFF`. It takes no parameters and returns no result sets.

```sql
exec z.usp_CleanupBackupRestoreObjects;
```

The procedure is intentionally unscheduled so you can invoke it on demand or include it in your own maintenance schedule. Inspecting active parent `CONTEXT_INFO` markers across all sessions requires `VIEW SERVER STATE` on SQL Server 2019 or `VIEW SERVER PERFORMANCE STATE` on SQL Server 2022 and later; without that permission, the procedure throws error `50000` before inspecting or deleting any objects. Removing discovered leftovers also requires permission to delete temporary jobs in `msdb` and drop procedures in schema `z`.

## Cleanup behavior

For each discovered multi-threaded backup or restore run ID across Schema Z procedures (`z.usp_BackupDatabaseExecutor_<RunID>`, `z.usp_BackupDatabaseWorker_<RunID>_*`, `z.usp_RestoreDatabaseExecutor_<RunID>`, `z.usp_RestoreDatabaseWorker_<RunID>_*`) and matching temporary SQL Server Agent jobs (`z_(<db>)_BackupDatabase_<RunID>_*`, `z_(<db>)_RestoreDatabase_<RunID>_*`):

1. **Active parent check**: If any active request in `sys.dm_exec_requests` still carries that run's `CONTEXT_INFO` token (`z.BackupDatabase:<RunID>` or `z.RestoreDatabase:<RunID>`), the entire run is skipped untouched.
2. **Running job check**: If any temporary Agent job belonging to that run is still executing (`z.fn_IsSQLJobRunning`), cleanup skips that run so active workers can finish draining and self-drop cleanly.
3. **Idle job and procedure removal**: Idle leftover jobs are re-checked with `z.fn_IsSQLJobRunning` and deleted individually through [z.usp_RemoveServiceJob](../../../010-Jobs/docs/reference/z.usp_RemoveServiceJob.md). If any job for that run is detected running afterward, procedure removal for that run is skipped. Otherwise, leftover worker procedures are dropped first and the executor procedure last, each after acquiring its `z.ExecuteProcedures:<object_id>` semaphore with `@LockTimeout = 0` so no actively executing procedure is dropped mid-call.
