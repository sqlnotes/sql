# Backup troubleshooting

[Subsystem](readme.md) | [Object reference](reference/readme.md)

Run one backup invocation at a time. There is no shared status view, worker pool or resumable batch. Every call processes its selected databases again. Errors stop remaining work and propagate to the caller. Native history in msdb records successful backups; no extended-property status is maintained.

The procedure does not prevalidate paths. Check native directory/backup errors and SQL Server service-account access. Filesystem destinations use local or UNC paths on Windows and local or mounted paths on Linux. Windows non-URL forward slashes are normalized to backslashes. A NULL folder falls back to InstanceDefaultBackupPath. Unknown or ineligible database selectors can produce no work. Offline databases and snapshots can fail at native BACKUP execution.

Azure HTTPS and S3 URLs use BACKUP TO URL and skip directory creation. Configure credentials and storage access before use; a URL is a container/bucket base with optional prefix. ServerName is a naming override, not a remote connection. S3 requires SQL Server 2022 or later. Native provider errors propagate.

Retention is separate from backup. Default filesystem retention trusts recognized filenames and preserves unrecognized names. Use header mode for irregular files. Missing full anchors, ambiguous media or dependency uncertainty can prevent deletion. Preview with the [cleanup helper](reference/z.usp_CleanupDatabaseBackups.md). The helper's deletion-scope validation is independent of backup path handling.

The backup procedure has no application lock. Cleanup retains its own lock during deletion, but active backups do not participate. Schedule standalone cleanup separately from backups. Filesystem actions cannot be rolled back.

The parameterless Full/Log wrappers contain a fixed UNC destination. The separate snapshot procedure has its own path-length and quoting limitations. Review each callable reference before execution.
