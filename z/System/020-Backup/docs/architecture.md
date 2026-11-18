# Backup architecture

[Subsystem](readme.md) | [Object index](reference/readme.md)

## Installation and dependencies

The subsystem installs in System's alphabetical child order. Shared System modules precede feature children; System post scripts follow them. See [System documentation](../../docs/readme.md).

Uses server catalogs, msdb backup history, filesystem operations and native backup/create-database commands. Filesystem destinations need SQL Server service-account access; URL destinations need configured SQL Server credentials and storage permissions. Windows supports local folders and UNC shares; Linux uses local or mounted filesystem paths.

## Backup flow

`z.usp_BackupDatabase` resolves a database list and processes it once, sequentially by data-file size. For each database it creates a directory for filesystem destinations only, then performs native BACKUP TO DISK or BACKUP TO URL. A native backup error stops the call; previous files remain. New calls start fresh. For bounded parallel work, `z.usp_BackupDatabasesParallel` composes a separate
TaskQueue batch and launches Agent workers through Jobs. The sequential procedure
has no shared assignments or persistent execution status of its own.

The backup procedure has no application lock. The cleanup helper locks only while cleaning up; it does not coordinate with active backups. Schedule standalone cleanup separately from backups.

Stop existing backup workers before upgrading. The [Backup post script](../post/DeprecatedObject.sql) removes the retired status view and trigger. Old backup extended properties are no longer used or maintained; their presence does not affect execution.

## Destinations, retention and reporting

Azure HTTPS and S3 URLs use forward slashes on either operating system and retain their case. URL destinations skip filesystem operations. ServerName defaults to @@servername and only controls the naming prefix. Storage credentials and containers/buckets must already exist. S3 requires SQL Server 2022 or later.

Retention is never called by the backup procedure. `z.usp_CleanupDatabaseBackups` inventories files in the selected database's FULL, DIFF and LOG folders. Filename mode recognizes current seven-digit and legacy timestamp formats without opening headers. Header mode checks metadata dependencies and supports irregular names. Unrecognized names are preserved in filename mode. Neither mode guarantees complete recovery coverage. See [cleanup reference](reference/z.usp_CleanupDatabaseBackups.md).

`z.v_BackupRestore` reads msdb reporting history independently; that history does not choose deletion candidates. `z.usp_CreateDatabaseSnapshot` is separate from retention. The parameterless Full/Log wrappers use a fixed UNC destination; inspect them before use.

## Restore flow

1. `z.usp_RestoreDatabase` inventories a local file, recursive filesystem folder or single backup-object URL. Recognized filenames guide discovery order. Native headers establish source identity, recovery fork, LSN coverage and the position of appended sets. Striped backups require separate tooling.
2. `z.usp_RestoreDatabaseTarget` builds a plan for each destination. Missing destinations need an applicable full. Continuing a restoring or standby database uses its native family, fork and redo state. Logs take priority when they reach the latest eligible endpoint. A matching differential can bridge a gap before subsequent logs. System and hosting databases, snapshots and availability-group targets have additional protections described in the [restore reference](reference/z.usp_RestoreDatabase.md).
3. The planner saves commands and file mappings for all targets before execution. Newly introduced files receive MOVE clauses at the restore step that introduces them. Output-path reservations protect against collisions within the same call.
4. `@ShowPlan = 1` returns those commands, mappings and outcomes after metadata inspection. `z.usp_RestoreDatabaseExecute` executes the same saved commands in order. The default leaves targets in NORECOVERY. Select RECOVERY or STANDBY for another final state.

When the target is omitted, each source uses its database name or an identifiable existing continuation target. Existing ONLINE or unavailable targets are skipped. An explicit name allows initialization under another name and guarded replacement of an existing database. Review automatic and explicit [target-selection rules](reference/z.usp_RestoreDatabase.md) before executing a restore.

Restores execute outside a user transaction. Completed steps remain applied if a later one fails. `@DropConnections = 1` can place an existing ONLINE destination in SINGLE_USER WITH ROLLBACK IMMEDIATE. Cleanup restores the prior access mode only while the same destination is ONLINE. A source can fail while independent targets proceed. Inspect each outcome and its planned commands.
