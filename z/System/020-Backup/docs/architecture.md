# Backup architecture

[Subsystem](readme.md) | [Object index](reference/readme.md)

Backup uses SQL Server's native backup and restore commands. The module selects databases or backup media, supplies file names and options, manages optional filesystem retention, and provides previews and history views around those operations.

## Installation and dependencies

The subsystem installs in System's alphabetical child order. Shared System modules precede feature children; System post scripts follow them. See [System documentation](../../docs/readme.md).

Uses server catalogs, msdb backup history, filesystem operations and native backup/create-database commands. Filesystem destinations need SQL Server service-account access; URL destinations need configured SQL Server credentials and storage permissions. Windows supports local folders and UNC shares; Linux uses local or mounted filesystem paths. Multi-threaded backups (`@Threads > 1`) also coordinate via `z.usp_ExecuteProcedures` semaphores and temporary SQL Server Agent jobs from `010-Jobs`.

## Backup flow

`z.usp_BackupDatabase` validates all inputs and resolves the database list once. When `@Threads = 1` (default) or only one database is selected, it runs inline from smallest to largest data-file size: creating a directory for filesystem destinations only, executing native `BACKUP TO DISK` or `BACKUP TO URL`, running optional `@RetentionHours` cleanup, and recording the outcome in `z.BackupRestoreHistory` (`PS_SchemaZPartitionGeneric` with `DATA_COMPRESSION = ROW`, truncated automatically by Partition maintenance). If a database fails, the procedure logs the failure, skips to the remaining databases, and raises a summary error after completing the pass.

When `@Threads > 1` with multiple selected databases, `z.usp_BackupDatabase` sets a run-specific `CONTEXT_INFO` liveness marker, creates one temporary executor procedure and one self-dropping per-database backup procedure per target (ordered largest-first) in schema `z`, and launches `min(@Threads, database count)` temporary self-deleting SQL Server Agent jobs via `010-Jobs`. Each job invokes the executor procedure, which uses `z.usp_ExecuteProcedures` to claim and execute remaining per-database procedures one by one without duplicate execution. If the parent request is cancelled or stopped, its `CONTEXT_INFO` marker disappears from active requests, causing remaining worker procedures to skip their backups and drop themselves. If all remaining started worker jobs stop running without Agent auto-deleting them across 5 consecutive 1-second checks, the parent removes those leftover jobs, drops remaining temporary procedures, and raises error `50000`. Once all worker jobs finish, the parent restores `CONTEXT_INFO`, drops the executor procedure, checks `z.BackupRestoreHistory` for the shared run `BatchID`, and raises a summary `50000` error if any database failed. If a parent session terminates unexpectedly before cleanup runs, call [z.usp_CleanupBackupRestoreObjects](reference/z.usp_CleanupBackupRestoreObjects.md) to remove leftover procedures and idle temporary jobs.

`z.usp_BackupDatabase` and `z.usp_CleanupDatabaseBackups` do not acquire application locks directly (`z.usp_ExecuteProcedures` coordinates concurrent multi-threaded workers per generated procedure). Cleanup skips invalid inputs and active/implicit transactions quietly and deletes expired files best-effort without throwing T-SQL exceptions, though `master.sys.xp_delete_files` emits error `22049` to the client stream if an OS lock blocks deletion of an eligible file.

Stop existing backup workers before upgrading. The [Backup post script](../post/DeprecatedObject.sql) removes retired backup objects, including `z.usp_BackupDatabasesParallel`, the retired status view, and its trigger. Old backup extended properties are no longer used or maintained; their presence does not affect execution.

## Destinations, retention and reporting

Azure HTTPS and S3 URLs use forward slashes on either operating system and retain their case. URL destinations skip filesystem operations. ServerName defaults to @@servername and only controls the naming prefix. Storage credentials and containers/buckets must already exist. S3 requires SQL Server 2022 or later.

By default (`@RetentionHours = null`), backups do not delete older files. When `@RetentionHours` is set on `z.usp_BackupDatabase`, filesystem backups invoke `z.usp_CleanupDatabaseBackups` on each database's folder after the backup completes using filename mode (`@UseBackupHeader = 0`), `@BackupType = @BackupType` and `@KeepLatestChain = 1`. `z.usp_CleanupDatabaseBackups` operates purely on `@BackupFolder` without consulting `sys.databases`, recursively inventories single-database or multi-database directory trees, supports separate retention policies per `@BackupType`, and when `@KeepLatestChain = 1` in filename mode retains either each database's latest regular `.bak` full + latest active `DIFF` + 1 predecessor log + subsequent logs (when an active `DIFF` exists) or its newest full (`.bak` or `.copyonly.bak`) + 1 predecessor log + subsequent logs (when no active `DIFF` exists), even when `@RetentionHours` is shorter. Set `@KeepLatestChain = 0` for pure age-based deletion or `@UseBackupHeader = 1` for standalone header-based cleanup on custom filenames. See [cleanup reference](reference/z.usp_CleanupDatabaseBackups.md).

`z.v_BackupRestore` reads msdb reporting history independently; that history does not choose deletion candidates. `z.usp_CreateDatabaseSnapshot` is separate from retention. The parameterless Full/Log wrappers use a fixed UNC destination; inspect them before use.

## Restore flow

1. `z.usp_RestoreDatabase` inventories a local file, recursive filesystem folder or single backup-object URL. Recognized filenames guide discovery order. Native headers establish source identity, recovery fork, LSN coverage and the position of appended sets. Striped backups require separate tooling.
2. `z.usp_RestoreDatabaseTarget` builds a plan for each destination. Missing destinations need an applicable full. Continuing a restoring or standby database uses its native family, fork and redo state. Logs take priority when they reach the latest eligible endpoint. A matching differential can bridge a gap before subsequent logs. System and hosting databases, snapshots and availability-group targets have additional protections described in the [restore reference](reference/z.usp_RestoreDatabase.md).
3. The planner saves commands and file mappings for all targets before execution. Newly introduced files receive MOVE clauses at the restore step that introduces them. Output-path reservations protect against collisions within the same call.
4. `@ShowPlan = 1` returns those commands, mappings and outcomes after metadata inspection. `z.usp_RestoreDatabaseExecute` executes the same saved commands in order and records executed steps and failures in `z.BackupRestoreHistory`. The default leaves targets in NORECOVERY. Select RECOVERY or STANDBY for another final state.

When the target is omitted, each source uses its database name or an identifiable existing continuation target. Existing ONLINE or unavailable targets are skipped. An explicit name allows initialization under another name and guarded replacement of an existing database. Review automatic and explicit [target-selection rules](reference/z.usp_RestoreDatabase.md) before executing a restore.

Restores execute outside a user transaction. Completed steps remain applied if a later one fails. `@DropConnections = 1` can place an existing ONLINE destination in SINGLE_USER WITH ROLLBACK IMMEDIATE. Cleanup restores the prior access mode only while the same destination is ONLINE. A source can fail while independent targets proceed. Inspect each outcome and its planned commands.
