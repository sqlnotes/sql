# z.usp_CleanupDatabaseBackups

[Backup](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_CleanupDatabaseBackups.sql)

## Purpose and scope

Inventory backup files directly inside one database's FULL, DIFF and LOG directories. By default, use the filename convention to plan cleanup without reading backup headers. Set `UseBackupHeader = 1` to use native backup metadata for irregular or legacy filenames. No `msdb` history determines cleanup.

The database-level folder must be an absolute Windows local/UNC path or an absolute Linux path. Mount Linux network shares before calling. Supply the parent of the three backup-type folders, not the overall backup destination root.

## Parameters

```text
@DatabaseName sysname,
@DatabaseBackupFolder nvarchar(max),
@RetentionHours int,
@ShowPlan bit = 0,
@UseBackupHeader bit = 0
```

Positive retention hours define a cutoff. `NULL` disables cleanup; zero and negative values are invalid. `ShowPlan = 1` returns the plan without deleting files.

The folder input is checked against the 4,000 UTF-16 code-unit internal path limit before conversion; longer inputs are rejected.

Native backup paths have a smaller limit: the complete filename must fit within 259 UTF-16 code units. The backup procedure leaves unusable paths to native directory and backup operations. Filename mode preserves individual files with unsupported path lengths or wildcard/control characters. In header mode those files prevent cleanup for the whole inventory. Folder inputs reject wildcard/control characters, dot segments, repeated separators and Windows trailing-dot/space aliases.

## Default: filename-based cleanup

Accept only the generated convention, including the sanitized database-name prefix and exactly six fractional digits:

```text
FULL/<DatabaseName>_yyyyMMdd_HHmmss_ffffff.bak
DIFF/<DatabaseName>_yyyyMMdd_HHmmss_ffffff.diff
LOG/<DatabaseName>_yyyyMMdd_HHmmss_ffffff.trn
```

The timestamp is SQL Server's local time. Folder, extension, digit count and calendar date must match. Preserve malformed names, different database prefixes and older seven-digit names; they do not become deletion candidates.

Keep the latest recognized full filename at or before the cutoff, all recognized backups at or after that timestamp, and the immediately preceding recognized log file. Without a recognized full anchor, preserve everything. Older recognized files can be deleted. Recheck inventory membership, sizes and modification times before deletion.

If another database currently listed in `sys.databases` maps to the same sanitized filename prefix, preserve the whole inventory. For example, `A B` and `A_B` share a prefix. This guard includes offline databases, but cannot identify historical ownership after a conflicting database has been dropped.

This mode trusts managed filenames. It does not inspect database identity, copy-only flags, differential bases or LSNs, and does not prove a recoverable chain. Preserving an irregular file does not establish its dependencies. Use header mode when those checks are needed, including inventories containing copy-only backups or mixed database identities.

## Optional: header-based cleanup

With `UseBackupHeader = 1`, inspect all relevant backup-shaped files, regardless of their naming, using native `RESTORE LABELONLY` and `RESTORE HEADERONLY`:

- Require understood, single-file, single-set, nonmirrored full, differential or log backups matching the current database lineage and recovery fork.
- Keep the newest usable ordinary full backup completed at or before the cutoff. Without such an anchor, preserve the whole inventory.
- Keep the anchor, newer backups and overlapping logs. Retained differential backups must have an identifiable retained full base.
- An unreadable, unsupported or ambiguous relevant file blocks deletion across the database inventory. Other file types are outside cleanup.
- Recheck all inventoried metadata and inventory membership before deletion, delete exact paths, and check native return codes and actual disappearance.

Retention is conservative and may keep files longer than the requested hours. It does not establish that every point in the window is recoverable: missing log files, corruption, external backup consumers and backups elsewhere remain outside that proof. Header reads do not replace restore tests.

## Coordination and failures

This helper uses an exclusive session application lock on the managed database folder to coordinate cleanup calls. The backup procedure does not hold that lock while writing. Schedule cleanup separately from active backups. A competing cleanup call reports a busy-lock failure without deleting files. Call outside a transaction. Filesystem actions cannot be rolled back. Treat managed folders as trusted storage: application locks coordinate participating calls in the same SQL Server database, not arbitrary filesystem writers or other servers.

Requires database catalog access, directory enumeration and file deletion rights. Header mode additionally requires backup metadata permissions; SQL Server 2019 through 2025 header layouts are handled explicitly, and unsupported layouts must not produce deletion candidates. Filename mode does not execute header or label reads.
