# Backup

[System documentation](../../docs/readme.md)

Run full, differential, or transaction-log backups; restore full, differential and log backups; report msdb backup/restore history; create database snapshots.

## Start here

- [Usage and examples](usage.md)
- [Architecture and dependencies](architecture.md)
- [Object reference](reference/readme.md)
- [Troubleshooting and current limitations](troubleshooting.md)

## Operational scope

Backups run sequentially to filesystem folders, Azure Blob HTTPS URLs or S3-compatible URLs (SQL Server 2022+). The nullable ServerName parameter changes the server/instance destination prefix; NULL uses @@servername. The procedure creates filesystem directories when needed, uses object prefixes for URLs, and never deletes old backups. Retention is a separate operation through the [filesystem cleanup procedure](reference/z.usp_CleanupDatabaseBackups.md) or provider lifecycle rules for URL objects.

Windows destinations can use absolute local or UNC paths. Linux destinations use absolute filesystem paths, including mounted network shares. The parameterless Full/Log wrappers contain a fixed UNC destination; inspect them before use.

[z.usp_RestoreDatabase](reference/z.usp_RestoreDatabase.md) accepts a backup file, a
specific HTTP(S)/S3 backup-object URL or a recursive filesystem folder. Mixed
folders and appended backup files use the same source-selection rules. Omit the
target to initialize missing user databases and continue matching restoring/standby
databases under their source names; existing ONLINE/unavailable targets are skipped.
An explicit missing target requires one usable full-backed source family and can
rename that source. Logs are preferred when sufficient; a compatible differential
is considered when needed to reach a later endpoint. URL inputs identify one
object without remote folder discovery. Preview chains, file mappings and outcomes
with ShowPlan = 1. The recovery default remains NORECOVERY; explicit replacement
retains the ReplaceExisting control.

DropConnections defaults to 1: an existing ONLINE target with pending commands uses
SINGLE_USER WITH ROLLBACK IMMEDIATE before restore. Unavailable destinations skip
this step. Preview shows access-mode actions without executing them.

## Inspect history and activity

Inspect recorded backups with z.v_BackupHistory, restores with z.v_RestoreHistory,
and active native commands with z.v_BackupRestoreRequests. See the
[inspection reference](reference/backup-restore-history.md) for row counts,
permissions and examples.

## Prerequisites

Uses sys.databases, sys.master_files, msdb backup/restore history, filesystem operations, and native backup/restore/create database commands. Filesystem destinations require SQL Server service-account access. URL backup destinations require configured SQL Server credentials and storage permissions.

For S3, use [z.usp_CreateS3BackupCredential](reference/z.usp_CreateS3BackupCredential.md) to create the URL-named credential or explicitly rotate its keys. This requires server-level credential permissions.

Use [z.usp_ReadBackupHeader](reference/z.usp_ReadBackupHeader.md) to read LSNs and the full backup-header metadata directly from a disk file or URL, with consistent columns across supported SQL Server versions.

[ReadBackupFileList](reference/z.usp_ReadBackupFileList.md) reports the database files in a selected backup set. The [header](reference/z.fn_DecodeBackupHeader.md) and [file-list](reference/z.fn_DecodeBackupFileList.md) JSON decoder functions expose typed rows for filtering, joins and INSERT SELECT.
