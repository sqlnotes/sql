# Backup

[System documentation](../../docs/readme.md)

Use Backup to protect SQL Server databases, restore them to the same or a different database name, and inspect backup and restore activity. It works with native SQL Server backup files, local or shared folders, and supported cloud-storage URLs.

## Start here

- [Usage and examples](usage.md)
- [Architecture and dependencies](architecture.md)
- [Object reference](reference/readme.md)
- [Troubleshooting and current limitations](troubleshooting.md)

## Operational scope

Choose the operation that matches your task:

| Task | Use |
| --- | --- |
| Back up databases sequentially or concurrently | [z.usp_BackupDatabase](reference/z.usp_BackupDatabase.md), using `@Threads = 1` (default) for inline sequential runs or `@Threads > 1` for bounded SQL Server Agent workers |
| Restore a database or keep a secondary up to date | [Restore](reference/z.usp_RestoreDatabase.md), with an optional preview of commands and file destinations |
| Remove old backup files | `@RetentionHours` on `z.usp_BackupDatabase`, or standalone [filesystem cleanup](reference/z.usp_CleanupDatabaseBackups.md) |
| Remove leftover parallel backup/restore objects | [z.usp_CleanupBackupRestoreObjects](reference/z.usp_CleanupBackupRestoreObjects.md) after an interrupted multi-threaded run |
| Inspect media or recorded operations | [Header reader](reference/z.usp_ReadBackupHeader.md), [file-list reader](reference/z.usp_ReadBackupFileList.md), and [history/activity views](reference/backup-restore-history.md) |

Use [z.usp_BackupDatabase](reference/z.usp_BackupDatabase.md) to process selected databases one at a time (`@Threads = 1`) or concurrently across bounded SQL Server Agent workers (`@Threads > 1`). Destinations include filesystem folders, Azure Blob HTTPS URLs and S3-compatible URLs (SQL Server 2022+). The nullable ServerName parameter changes the server/instance destination prefix; NULL uses @@servername. By default, backups use `<BackupFolder>/<Server>/<Instance>/<Database>/<BackupType>/`; set `@CreateServerInstanceFolder = 0` to omit `<Server>/<Instance>/` and `@CreateBackupTypeFolder = 0` to place all backup types directly in `<Database>/`. The procedure creates filesystem directories when needed and uses object prefixes for URLs. By default (`@RetentionHours = null`), old backups are not deleted; set `@RetentionHours` to remove expired filesystem backups of that backup type (preserving the latest recovery chain), use the [filesystem cleanup procedure](reference/z.usp_CleanupDatabaseBackups.md) directly, or use provider lifecycle rules for URL objects.

Windows destinations can use absolute local or UNC paths. Linux destinations use absolute filesystem paths, including mounted network shares. The parameterless Full/Log wrappers contain a fixed UNC destination; inspect them before use.

[z.usp_RestoreDatabase](reference/z.usp_RestoreDatabase.md) accepts a backup file, a
specific HTTP(S)/S3 backup-object URL or a recursive filesystem folder. Mixed
folders and appended backup files use the same source-selection rules. Omit the
target to initialize missing user databases and continue matching restoring/standby
databases under their source names; existing ONLINE/unavailable targets are skipped.
An explicit missing target uses the unique full-backed source family (allowing
rename) or the unique family matching `@TargetDatabaseName` in a multi-database folder.
Logs are preferred when sufficient; a compatible differential
is considered when needed to reach a later endpoint. URL inputs identify one
object without remote folder discovery. Preview chains, file mappings and outcomes
with ShowPlan = 1. The recovery default remains NORECOVERY; explicit replacement
retains the ReplaceExisting control.

DropConnections defaults to 1: an existing ONLINE target with pending commands uses
SINGLE_USER WITH ROLLBACK IMMEDIATE before restore. Unavailable destinations skip
this step. Preview shows access-mode actions without executing them.

## Inspect history and activity

Inspect subsystem execution history (including failed attempts) in `z.BackupRestoreHistory` without querying `msdb`, native backup sets with `z.v_BackupHistory`, native restores with `z.v_RestoreHistory`, and active native commands with `z.v_BackupRestoreRequests`. See the [inspection reference](reference/backup-restore-history.md) for retention, row counts, permissions and examples.

## Prerequisites

Uses sys.databases, sys.master_files, msdb backup/restore history, filesystem operations, and native backup/restore/create database commands. Filesystem destinations require SQL Server service-account access. URL backup destinations require configured SQL Server credentials and storage permissions.

For S3, use [z.usp_CreateS3BackupCredential](reference/z.usp_CreateS3BackupCredential.md) to create the URL-named credential or explicitly rotate its keys. This requires server-level credential permissions.

Use [z.usp_ReadBackupHeader](reference/z.usp_ReadBackupHeader.md) to read LSNs and the full backup-header metadata directly from a disk file or URL, with consistent columns across supported SQL Server versions.

[ReadBackupFileList](reference/z.usp_ReadBackupFileList.md) reports the database files in a selected backup set. The [header](reference/z.fn_DecodeBackupHeader.md) and [file-list](reference/z.fn_DecodeBackupFileList.md) JSON decoder functions expose typed rows for filtering, joins and INSERT SELECT.
