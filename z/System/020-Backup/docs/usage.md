# Backup usage

[Subsystem](readme.md) | [Object reference](reference/readme.md)

## Examples

Inspect recorded backup state from the database containing the Backup modules:

```sql
select DatabaseID, DatabaseName, BackupType, IsReadOnly, RunID, SettingsHash, SessionID,
	StartDate, EndDate, BackupStatus, MetadataStatus
from z.v_DatabaseBackupStatus;
```

The [status view and update trigger](reference/z.v_DatabaseBackupStatus.md) persist status centrally, so read-only targets need no extended-property writes. Filter by BackupType when updating one operation. Callers can update RunID, SettingsHash, SessionID, StartDate and EndDate through the view within a transaction. Backup ownership and native backup execution remain the caller's responsibility.

Execute against a database containing System and this subsystem. Examples describe current interfaces; environment permissions and data determine results.

For parallel backups, create X jobs with the same call, all executing from the same coordination database through separate SQL connections. Start them together. Each session takes available unfinished databases, then returns for more until the set completes. No fixed database partition per job is required. Use matching settings within a backup type while sessions are active:

```sql
exec z.usp_BackupDatabase
	@Databases = N'Application,Reporting,Archive',
	@BackupFolder = N'D:\Backup',
	@BackupType = N'FULL',
	@RetentionHours = 48;
```

On Linux, replace the destination with an absolute mounted path such as `/mnt/backup`. List order does not change the RunID. FULL and DIFF requests for one database wait for each other; LOG can proceed alongside either, subject to native prerequisites. Each type has independent status. Another call after the batch finishes starts fresh; a retry of an inactive unfinished batch preserves completed databases. Close each connection after canceling its request. Review [parallel ownership and recovery](reference/z.usp_BackupDatabase.md#parallel-sessions) before using overlapping sets.

```sql
select DatabaseName, BackupType, BackupFinishDate, LatestBackupLocation
from z.v_BackupRestore
where DatabaseName = db_name();
```

Backup execution can delete earlier files in the selected database's managed folders. Retention is positive hours or `NULL` to disable cleanup. The parameterless Full/Log wrappers contain a fixed UNC destination; inspect them before use.

Preview cleanup independently by supplying the database-level directory, which contains FULL, DIFF and LOG subfolders:

```sql
exec z.usp_CleanupDatabaseBackups
	@DatabaseName = N'Application',
	@DatabaseBackupFolder = N'D:\Backup\Server\MSSQLSERVER\Application',
	@RetentionHours = 48,
	@ShowPlan = 1;
```

On Linux, use the corresponding absolute path, for example `/mnt/backup/Server/MSSQLSERVER/Application`. Default preview uses filenames and filesystem metadata, without opening backup headers. Add `@UseBackupHeader = 1` to select header-based cleanup for legacy or irregular filenames. The option is also available on `z.usp_BackupDatabase`. Check the [cleanup reference](reference/z.usp_CleanupDatabaseBackups.md) before execution.
