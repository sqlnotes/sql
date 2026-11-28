# Backup troubleshooting

[Subsystem](readme.md) | [Object reference](reference/readme.md)

The sequential procedure processes its selected databases again on every call. If a database backup fails, it records the failure in `z.BackupRestoreHistory`, continues with the remaining selected databases, and raises a summary error at the end. Runtime native `BACKUP` and `RESTORE` failures caught in T-SQL report SQL Server error `3013` in `z.BackupRestoreHistory` (whereas option syntax failures record their direct SQL error such as `155`); inspect the SQL Server error log for underlying device or LSN details. For a parallel call, use `z.BackupRestoreHistory` and its retained TaskQueue batch and task rows to see individual outcomes. [Parallel backup](reference/z.usp_BackupDatabasesParallel.md)

The procedure does not prevalidate paths. Check native directory/backup errors and SQL Server service-account access. Filesystem destinations use local or UNC paths on Windows and local or mounted paths on Linux. Windows non-URL forward slashes are normalized to backslashes. A NULL folder falls back to InstanceDefaultBackupPath. Unknown or ineligible database selectors can produce no work. Offline databases and snapshots can fail at native BACKUP execution.

Azure HTTPS and S3 URLs use BACKUP TO URL and skip directory creation. Configure credentials and storage access before use; a URL is a container/bucket base with optional prefix. ServerName is a naming override, not a remote connection. S3 requires SQL Server 2022 or later. Native provider errors propagate.

Filesystem retention (`@RetentionHours` on backup procedures or standalone [z.usp_CleanupDatabaseBackups](reference/z.usp_CleanupDatabaseBackups.md)) operates best-effort without throwing T-SQL exceptions or returning result sets: if a file is locked or cannot be deleted, `master.sys.xp_delete_files` emits extended-procedure error `22049` (severity 16) to the client stream while T-SQL leaves that file on disk and continues deleting remaining eligible files. Schedule standalone cleanup separately if concurrent readers lock expired files and a client-side `22049` message would fail a backup job step. Default filename mode (`@UseBackupHeader = 0`) never reads backup headers, recognizes `.bak`, `.copyonly.bak`, `.diff`, `.trn` and `.copyonly.trn` filenames, and preserves unrecognized names; use `@UseBackupHeader = 1` on standalone calls when backup files do not use standard names. With `@KeepLatestChain = 1` (default), cleanup preserves the latest regular `.bak` + latest active `DIFF` + 1 predecessor log + subsequent logs when an active `DIFF` exists (letting expired `.copyonly.bak` files age out), or the newest full (`.bak` or `.copyonly.bak`) + 1 predecessor log + subsequent logs when no active `DIFF` exists; pass `@KeepLatestChain = 0` to delete strictly by cutoff age.

Neither the backup procedure nor the cleanup helper uses application locks. Filesystem actions cannot be rolled back.

The parameterless Full/Log wrappers contain a fixed UNC destination. The separate snapshot procedure has its own path-length and quoting limitations. Review each callable reference before execution.

## Restore failures

Preview with [z.usp_RestoreDatabase](reference/z.usp_RestoreDatabase.md) ShowPlan = 1.
Mixed folders and files containing appended backup sets are supported. Inspect
the selected source and per-database outcomes before execution. A missing explicit
target selects the unique full-backed source family (allowing rename) or the unique
family matching `@TargetDatabaseName` in a multi-database folder; several full backups
of one family count once. Unrelated standalone logs/differentials do not add
initialization candidates. Omit the target for automatic per-source processing;
existing ONLINE/unavailable databases are skipped rather than replaced. Sources
without a full cannot initialize a missing destination. Recognized names permit newest-first header reads
that stop once the chain is complete. Nonconforming names all require headers;
large collections of those files can take longer to plan.
A log gap, unsupported recovery-fork transition or unavailable destination progress
without a compatible fallback stops that database's planning rather than silently
restarting it. Missing optional differential history does not prevent valid native
log continuation. Other automatic sources continue and failures remain visible
in the final outcomes and aggregate execution error.
An incompatible differential is not applied to a different full base. A standalone
differential requires its base already restored without recovery or subsequent
log restores; otherwise provide the full backup folder.

Choose UseDefaultFolder = 1 for instance-default directories or 0 for the backup's
original directories; explicit DataFolder/LogFolder overrides either choice.
Data/log directory existence is not checked during preview; native RESTORE reports
missing directories or access failures without redirecting to another folder.
DropConnections = 1 (the default) uses SINGLE_USER WITH ROLLBACK IMMEDIATE for an
existing ONLINE target with pending commands. Preview shows the action without
changing access mode. Native ALTER DATABASE permissions are needed. Applications
that reconnect can still take the single-user slot. Review access mode after a
failure or separate recovery from NORECOVERY; cleanup requires an ONLINE target.
Check destination directories, SQL Server service-account permissions, encryption
keys, disk capacity and active target connections. DataFolder/LogFolder choose
destinations for new files without moving existing continuation files.
Inspect AddedOrdinal in preview to see which command introduces each file.
File-ID/GUID reuse, removals and unsupported container layouts still stop planning.
Restore errors can leave a partially completed sequence; the procedure does not
undo completed steps.
Keep standby undo files available between restores. No live restore validation is
implied by a successful preview or by reading backup headers.
