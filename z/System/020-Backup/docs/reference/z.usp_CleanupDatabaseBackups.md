# z.usp_CleanupDatabaseBackups

[Backup](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_CleanupDatabaseBackups.sql)

## Purpose and scope

Removes expired `.bak`, `.copyonly.bak`, `.diff`, `.trn` and `.copyonly.trn` backup files recursively under `@BackupFolder` on a best-effort basis without throwing T-SQL exceptions, consulting `sys.databases`, or returning result sets. If a file cannot be deleted (for example, because another process holds it open), `master.sys.xp_delete_files` emits extended-procedure error `22049` (severity 16) to the client stream while T-SQL leaves that file in place and continues deleting remaining eligible candidates.

`z.usp_BackupDatabase` calls this procedure automatically on each database's folder after backing up to disk when `@RetentionHours` is specified, using `@UseBackupHeader = 0` and `@KeepLatestChain = 1`. You can also schedule `z.usp_CleanupDatabaseBackups` directly against a single database folder, an instance folder, or a multi-database root/log-shipping share—including backups for remote or dropped databases—to apply separate retention windows for `FULL`, `DIFF` and `LOG` backups or to use `@UseBackupHeader = 1` on custom filenames.

## Parameters

```sql
create or alter procedure z.usp_CleanupDatabaseBackups
(
	@BackupFolder nvarchar(4000),
	@RetentionHours int,
	@BackupType varchar(10) = null,
	@KeepLatestChain bit = 1,
	@UseBackupHeader bit = 0
)
```

| Parameter | Description |
| --- | --- |
| `@BackupFolder` | Filesystem folder on Windows (drive or UNC) or Linux to clean recursively (a single database folder, an instance folder, or a multi-database root). Missing or inaccessible folders return quietly. |
| `@RetentionHours` | Retention window in hours. `NULL` or nonpositive values perform no cleanup and return quietly. |
| `@BackupType` | Optional filter (`FULL`, `DIFF`, `LOG`, or `NULL`/`ALL` for all types) so each backup type can use its own retention schedule. |
| `@KeepLatestChain` | When `1` (default), preserves each database's latest recovery chain even if `@RetentionHours` is shorter. When an active `DIFF` exists against the latest regular `FULL`, the retained chain is that regular `FULL`, the latest `DIFF`, and required `LOG`s (`.trn` and `.copyonly.trn`); otherwise, it is the newest `FULL` (regular or `COPY_ONLY`) and its required `LOG`s. In filename mode (`@UseBackupHeader = 0`), it uses `.copyonly.*` extensions to distinguish copy-only backups and retains 1 predecessor `LOG` immediately before the chain anchor (`DIFF`, or `FULL` when no `DIFF` applies). When `0`, deletes expired files strictly by `@RetentionHours`. |
| `@UseBackupHeader` | When `0` (default), never reads backup headers; decodes recognized filenames via [z.fn_DecodeBackupFileName](z.fn_DecodeBackupFileName.md) (`.bak`, `.copyonly.bak`, `.diff`, `.trn`, `.copyonly.trn` with database name and UTC timestamp) and leaves unrecognized filenames untouched. When `1`, reads single-set backup headers via [z.usp_ReadBackupHeader](z.usp_ReadBackupHeader.md) using server-local `BackupFinishDate`, `(ServerName, DatabaseName)` grouping, and LSN/GUID chain relationships (useful for custom filenames outside the standard convention). |

## Retention and latest-chain rules

1. **Candidate selection**: Only `.bak`, `.copyonly.bak`, `.diff`, `.trn` and `.copyonly.trn` files under `@BackupFolder` whose timestamp is older than `@RetentionHours` (and whose type matches `@BackupType` when specified) become deletion candidates. Filename mode (`@UseBackupHeader = 0`) never reads backup headers; it groups files by container folder (merging `FULL`, `DIFF` and `LOG` subfolders with their parent database folder) and decoded database name, leaving unrecognized filenames untouched. Header mode (`@UseBackupHeader = 1`) groups by `(ServerName, DatabaseName)` from native backup headers and leaves unreadable headers and multi-set files untouched.
2. **Latest-chain protection (`@KeepLatestChain = 1`)**: Independently for each database source discovered under `@BackupFolder`, cleanup preserves the latest chain even when timestamps are older than `@RetentionHours`:
   - **Filename mode (`@UseBackupHeader = 0`)**: When at least one `DIFF` exists at or after the latest regular `.bak` full (or when a `DIFF` exists with no regular `.bak`), keeps that latest regular `.bak`, the latest `DIFF`, **1 predecessor `LOG` immediately before that `DIFF`** so start-time overlap never breaks point-in-time recovery, and all `LOG` backups (`.trn` and `.copyonly.trn`) at or after that `DIFF`, while allowing expired `.copyonly.bak` files to age out. When no active `DIFF` exists, keeps the newest `FULL` backup (`.bak` or `.copyonly.bak`), **1 predecessor `LOG` immediately before that `FULL`**, and all `LOG` backups at or after that `FULL`. Earlier `LOG` backups before that predecessor `LOG` can be deleted when older than `@RetentionHours`.
   - **Header mode (`@UseBackupHeader = 1`)**: When at least one undamaged `DIFF` matches the latest non-copy-only `FULL` (`d.DifferentialBaseGUID = RegularFull.BackupSetGUID`), keeps that regular `FULL`, the latest matching `DIFF`, and all `LOG` backups on that `FamilyGUID` whose `LastLSN >= Diff.LastLSN`, allowing expired `COPY_ONLY` fulls to age out. When no active `DIFF` applies, keeps the newest `FULL` (regular or `COPY_ONLY`) and all `LOG` backups on that `FamilyGUID` whose `LastLSN >= Full.FirstLSN`. Earlier `LOG` backups between the latest `FULL` and latest `DIFF` that are older than `@RetentionHours` can still be deleted because the retained `DIFF` supersedes them.
3. **Pure cutoff mode (`@KeepLatestChain = 0`)**: Deletes all recognized files of the selected `@BackupType` older than `@RetentionHours` across `@BackupFolder` without applying the latest-chain rule.

## Examples

```sql
-- Apply separate retention windows across an entire backup share while keeping each database's latest recovery chain.
exec z.usp_CleanupDatabaseBackups @BackupFolder = N'D:\Backup', @RetentionHours = 336, @BackupType = 'FULL';
exec z.usp_CleanupDatabaseBackups @BackupFolder = N'D:\Backup', @RetentionHours = 72,  @BackupType = 'DIFF';
exec z.usp_CleanupDatabaseBackups @BackupFolder = N'D:\Backup', @RetentionHours = 24,  @BackupType = 'LOG';

-- Pure age-based cleanup on a single database folder regardless of the latest-chain rule.
exec z.usp_CleanupDatabaseBackups @BackupFolder = N'D:\Backup\Sales', @RetentionHours = 168, @KeepLatestChain = 0;
```

## Operational notes

- Assumes SQL Server 2019 (15.x) or later, does not read `sys.databases` or `msdb`, and calls `master.sys.xp_delete_files` inside a `TRY...CATCH` per existing file.
- Acquires no application locks/semaphores, returns no result sets, and returns quietly without errors or deletions on invalid/missing inputs or when called inside an active or implicit transaction. When an eligible file is locked by another process, `master.sys.xp_delete_files` still surfaces native error `22049` (severity 16) on the client stream even though T-SQL continues past the file without aborting.
- Requires SQL Server service-account directory enumeration and file deletion permissions on `@BackupFolder`.
