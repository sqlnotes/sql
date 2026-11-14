# Backup troubleshooting

[Subsystem](readme.md) | [Object reference](reference/readme.md)

Run one backup invocation at a time. There is no shared status view, worker pool or resumable batch. Every call processes its selected databases again. Errors stop remaining work and propagate to the caller. Native history in msdb records successful backups; no extended-property status is maintained.

The procedure does not prevalidate paths. Check native directory/backup errors and SQL Server service-account access. Filesystem destinations use local or UNC paths on Windows and local or mounted paths on Linux. Windows non-URL forward slashes are normalized to backslashes. A NULL folder falls back to InstanceDefaultBackupPath. Unknown or ineligible database selectors can produce no work. Offline databases and snapshots can fail at native BACKUP execution.

Azure HTTPS and S3 URLs use BACKUP TO URL and skip directory creation. Configure credentials and storage access before use; a URL is a container/bucket base with optional prefix. ServerName is a naming override, not a remote connection. S3 requires SQL Server 2022 or later. Native provider errors propagate.

Retention is separate from backup. Default filesystem retention trusts recognized filenames and preserves unrecognized names. Use header mode for irregular files. Missing full anchors, ambiguous media or dependency uncertainty can prevent deletion. Preview with the [cleanup helper](reference/z.usp_CleanupDatabaseBackups.md). The helper's deletion-scope validation is independent of backup path handling.

The backup procedure has no application lock. Cleanup retains its own lock during deletion, but active backups do not participate. Schedule standalone cleanup separately from backups. Filesystem actions cannot be rolled back.

The parameterless Full/Log wrappers contain a fixed UNC destination. The separate snapshot procedure has its own path-length and quoting limitations. Review each callable reference before execution.

## Restore failures

Preview with [z.usp_RestoreDatabase](reference/z.usp_RestoreDatabase.md) ShowPlan = 1.
Mixed folders and files containing appended backup sets are supported. Inspect
the selected source and per-database outcomes before execution. A missing explicit
target requires exactly one usable full-backed source family; several full backups
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
