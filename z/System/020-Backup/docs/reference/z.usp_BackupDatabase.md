# z.usp_BackupDatabase

[Backup](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_BackupDatabase.sql)

## Purpose and behavior

1. Select databases from AllDatabases, UserDatabases, SystemDatabases, or a comma-separated list. Exclude tempdb and five error/recovery states; skip SIMPLE recovery for log backups.
2. Resolve the destination and register the sorted resolved database list as a SHA-256 RunID. Sessions in the same coordination database share unfinished work for `(RunID, BackupType)`, selecting available databases in ascending data-file size.
3. Create instance/database/backup-type subfolders if `sys.dm_os_file_exists` does not identify an existing directory. Filesystem access failures propagate from native operations.
4. Print and execute native backup SQL. `OtherBackupOptions` is appended as trusted SQL.
5. After each successful backup, try exclusive folder access and call `z.usp_CleanupDatabaseBackups` using the selected cleanup mode. Defer cleanup while the folder is busy.

## Cleanup scope

Retention inventories only the selected database's managed folders beneath `BackupFolder`. By default it uses the six-digit timestamp naming convention, retaining a full anchor and newer files while preserving unrecognized names. `UseBackupHeader = 1` selects header-based identity and dependency checks for irregular or legacy filenames. This removes physical files and does not prune `msdb` history. See [cleanup rules and preview](z.usp_CleanupDatabaseBackups.md).

## Transactions and failures

Call outside an existing transaction. The procedure commits short status transactions through `z.v_DatabaseBackupStatus` before native backup execution. Each database's backup and cleanup hold a session application lock. Previously completed backups and filesystem actions remain after errors. A failure can stop processing before later databases are backed up.

Completion is recorded after successful native BACKUP, before cleanup. Cleanup failure leaves the backup complete. Failure between native success and completion recording can cause a retry backup. Close the dedicated connection after cancellation so its session locks are released.

## Parallel sessions

Call the procedure from separate SQL connections in the same database containing the modules. The same resolved database set has the same RunID regardless of list order. Workers share work within `(RunID, BackupType)` and must use identical effective settings there. Inactive unfinished runs can resume with corrected settings without resetting completed databases. Once the previous batch has no active sessions and no unfinished assignments, another invocation starts a fresh batch. A job arriving after every worker has exited starts another batch; the list hash does not identify an arbitrarily delayed schedule wave.

A different database set takes ownership of overlapping assignments of the same backup type when it registers later. An already running backup finishes, but its completion cannot mark the newer assignment complete. FULL, DIFF and LOG assignments do not overwrite each other. A same-run/type session takes over unfinished work only after the previous execution lock becomes available. See [status persistence](z.v_DatabaseBackupStatus.md).

Settings correction resumes the existing intended operation within its backup type. It preserves every completed database even if the destination or other options change. Finish an unfinished batch before requesting a fresh backup of that same set/type with different semantics. FULL and LOG calls have independent status and worker groups.

Registration, claims, completion and pending checks use `z.v_DatabaseBackupStatus`. The trigger persists RunID and SettingsHash alongside each database's status. RunID hashes the binary-sorted resolved names serialized with `FOR JSON PATH` as UTF-16 bytes. SettingsHash hashes the effective type, destination, compression, extra options, retention and cleanup mode. The procedure reads and writes these values through the view.

Active joiners must match the hashes on rows still assigned to their RunID and type. A run whose assignments have all been superseded joins without taking work back. Inactive settings correction updates every still-owned typed row, including completed rows, while preserving session and start/end values. Legacy untyped properties are ignored; upgrade requires stopping old workers and starting fresh typed state.

Short exclusive transaction lock `z.Backup.Register` protects registration and status changes. Shared session lock `z.Backup.Run:<BackupType>:<RunID>` remains held for the invocation. FULL and DIFF use exclusive session lock `z.Backup.Database:<DatabaseID>:DATA`; LOG uses `z.Backup.Database:<DatabaseID>:LOG`. Conflicting workers skip busy databases and retry while unfinished work remains. A LOG backup can proceed alongside a FULL or DIFF backup, subject to native prerequisites.

Native backups hold a shared database-folder lock. After completion, that shared lock is released before trying an exclusive cleanup lock. Busy cleanup is deferred with a diagnostic; it does not invalidate the successful backup. A later backup or separate cleanup call must get another opportunity to enforce retention. All status transactions commit before native backup or filesystem work. Missing/stale assignments can be initialized by a new batch; invalid selected metadata causes an error. The procedure requires the status view and its update trigger to be installed.

## Parameters and defaults

```text
@Databases nvarchar(max) = 'AllDatabases',
@BackupType nvarchar(50) = 'Full',
@BackupFolder nvarchar(4000) = null,
@BackupCompression bit = 1,
@OtherBackupOptions nvarchar(max) = null,
@RetentionHours int = 30,
@UseBackupHeader bit = 0
```

These are the source-declared types and defaults.

## Results, permissions, and limits

Prints commands, native backup messages and cleanup diagnostics. Requires backup rights in every target, access to backup metadata and filesystem operations, and permission to add/update database-level extended properties in the coordination database. Compression null reads the server default. Retention null disables cleanup; zero and negative retention are rejected. This procedure executes backups immediately; use the cleanup helper's preview to inspect cleanup separately.

The complete generated backup filename must fit within 259 UTF-16 code units. Longer paths are rejected before directory creation; shorten the destination or database name rather than relying on filename truncation.

Filenames use `<DatabaseName>_yyyyMMdd_HHmmss_ffffff` followed by `.bak`, `.diff` or `.trn`. The timestamp is SQL Server's local time with an explicit Gregorian calendar; `ffffff` is exactly six zero-padded fractional-second digits (microseconds). The date, time and fraction come from one timestamp.

## Dependencies

Dependencies include `z.v_DatabaseBackupStatus`, `z.TRI_v_DatabaseBackupStatus`, `z.usp_CleanupDatabaseBackups`, native backup/header commands, application locks, `master.sys.xp_create_subdir`, `sys.configurations`, `sys.databases`, `sys.dm_os_host_info`, `sys.dm_os_file_exists` and `sys.master_files`.

Native BACKUP plus master.sys.xp_create_subdir and master..xp_delete_file are executed; filesystem changes are part of the operation.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
