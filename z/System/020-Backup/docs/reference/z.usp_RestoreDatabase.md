# z.usp_RestoreDatabase

[Object index](readme.md) | [Source](../../modules/1070%20Procedures/z.usp_RestoreDatabase.sql)

Restores a full database backup, an optional compatible differential and transaction logs, or continues a compatible
database already in RESTORING or standby. All paths are interpreted by SQL Server,
using the SQL Server service account's access.

```sql
create or alter procedure z.usp_RestoreDatabase
(
	@BackupPath nvarchar(4000),
	@TargetDatabaseName sysname = null,
	@RecoveryType varchar(10) = 'NORECOVERY',
	@ReplaceExisting bit = 1,
	@DataFolder nvarchar(4000) = null,
	@LogFolder nvarchar(4000) = null,
	@UseDefaultFolder bit = 1,
	@StandbyFolder nvarchar(4000) = null,
	@ShowPlan bit = 0,
	@DropConnections bit = 1,
	@OtherRestoreOptions nvarchar(max) = N'stats = 1'
)
```

## Source selection

A filesystem folder is searched recursively, with a limit of 4096 directories.
HTTP(S) and S3 paths identify one specific backup object and use FROM URL; the
procedure does not list remote folders, scan sibling objects or perform local
filesystem checks on a URL. URLs retain their case and forward slashes on Windows
and Linux. SQL Server credentials, endpoint/transport support and storage access
must already be configured; S3 requires SQL Server 2022 or later. Recognizing an
HTTP URL does not add transport support beyond the native SQL Server provider.
A folder may contain backups
from several databases. For initialization or replacement, a supplied TargetDatabaseName
prefers a matching source database. If none matches, select the latest full backup
as a rename source. Without TargetDatabaseName, select the latest full and use its source
name as the destination. Equal candidates use a deterministic path order.

After selecting the full, consider only its database family and recovery fork.
Restore the latest compatible differential if available, then the remaining log
chain. A differential must identify the selected full as its base; a copy-only
full cannot be a differential base. Differentials belonging to another full do
not change the selected full. Without a compatible differential, use full plus
logs; without pending logs, restore the selected data backups alone.

Managed filenames from z.usp_BackupDatabase use
`<database>_yyyyMMdd_HHmmss_ffffff.bak`, `.diff` and `.trn`. These names allow
newest-first candidate discovery without opening every older backup. Opened headers
confirm identity, type and LSNs. Arbitrary filenames require broader header
inspection. Managed mode trusts the embedded producer timestamp to order
candidates; it does not compare every full backup's header completion time.
A detected filename/header type or source mismatch switches to header discovery.
Multiple filename prefixes also use header discovery, because a source rename
can change the prefix while preserving its backup family and log chain.
Directory listing still covers the selected folder tree. Unreadable files in
general header discovery are skipped; errors opening managed candidates or
validating selected media stop planning.

A file or URL input considers only that object; it does not scan siblings. A standalone log
or differential requires an explicit TargetDatabaseName and a compatible unrecovered
destination. A differential alone cannot initialize a missing database. Existing
RESTORING or standby destinations use their verified restore identity and progress,
even when a different database has a newer full in the folder.

Log planning uses exact numeric LSNs, database family and recovery-fork identity.
Inspect candidate logs newest first until their collected coverage reaches the
required LSN, then execute the selected logs in forward LSN order. Include the
log overlapping the starting boundary; filename dates alone cannot prove coverage.
Already-covered backups are skipped. Gaps still fail rather than silently choosing
an older full. Recovery-fork transitions, file/filegroup restores, striped or
multi-set media and incomplete or damaged selected backup metadata are unsupported.

## Destination state and replacement

| Destination | Action |
| --- | --- |
| Missing | Restore full, optional differential, then logs |
| RESTORING or standby | Verify identity and progress, then apply pending compatible backups |
| Other state, ReplaceExisting = 1 | Restore full with REPLACE, optional differential, then logs |
| Other state, ReplaceExisting = 0 | Error |

Continuation takes precedence over replacement. An incompatible or unprovable
continuation fails; it never automatically replaces that database from full.
Continuation requires retained compatible msdb restore history, current recovery
metadata and matching physical-file identities. Database name alone is not proof
of identity. History must retain a compatible full-restore anchor and each base
file's latest mapping within that restore chain. A log restore need not repeat
data-file mappings and can omit the destination mapping for a newly added data
file. For that new-file case, continuation requires matching native file GUID
and creation LSN, compatible retained backup metadata and proof of the introducing
log interval or differential base. Its current catalog path is retained. Base
files still require their recorded destination mapping. Existing files retain
their current paths during continuation.
DataFolder/LogFolder apply to newly introduced files and may differ from the
existing files' directories. Stale non-full history predating the
destination's creation/rename timestamp is rejected. A full restore's recorded
start can precede creation of its destination; full history is instead bound by
the restore sequence, database family/fork and each file's latest GUID/path mapping.

Execute outside a user transaction. System databases, snapshots and the database
hosting the procedure cannot be restore targets. DropConnections defaults to 1.
Before restoring an existing ONLINE destination with pending commands, run
`ALTER DATABASE ... SET SINGLE_USER WITH ROLLBACK IMMEDIATE` to disconnect its
users and roll back their open transactions. Set DropConnections = 0 to skip this
step. No individual KILL commands or session enumeration are used. Missing,
RESTORING and other unavailable destinations do not need this access change.
An unchanged standby with no pending commands leaves its readers connected.

ShowPlan reports an ordinal-0 SINGLEUSER step and conditional ACCESSMODE cleanup
without executing either. Planning generates every action's SQL and stores it in
the final temporary plan table. Preview selects that table in ordinal order;
normal execution reads and executes those same rows, including access preparation,
media restores, finalization and guarded access-mode cleanup. The error handler
reuses the planned cleanup row. The destination identity is rechecked before execution.
After success or a caught failure, the procedure restores the original access
mode if it changed it and the same destination remains ONLINE. A secondary
cleanup failure is printed without hiding the original restore error.

NORECOVERY/RESTORING destinations cannot have their access mode cleaned up this
way; the procedure does not recover a database just to change access mode.
Native RESTORE can reset database options from the backup. Review access mode
after a later recovery if a previous call ended while the database was unavailable;
original mode is not persisted across separate calls. Native ALTER DATABASE and
restore permissions are required. Another connection can acquire the single-user
slot; pause reconnecting workloads if they keep interfering.

REPLACE can discard the existing target's data and
unbacked log; the procedure does not take a tail-log backup. Restoration is
sequential and is not rolled back as an encompassing transaction when a later
step fails. Correct the error and retry using the resulting database state.

## File destinations

Resolve data and log folders independently. An explicit DataFolder or LogFolder
always wins for its file type. For each unspecified folder, UseDefaultFolder = 1
(the default) uses InstanceDefaultDataPath or InstanceDefaultLogPath;
UseDefaultFolder = 0 retains that file's parent directory recorded in the backup.
There is no automatic fallback between original and default directories.
The procedure does not probe data/log directory existence or create directories;
native RESTORE reports missing or inaccessible folders. Preview can therefore
show mappings to folders that do not exist. Missing path metadata still fails.

Use named arguments for folder options. During continuation, existing destination
files stay in place; folder options and UseDefaultFolder choose destinations only
for newly introduced files. This applies even when the destination database name
matches the source name.

When restoring under another database name, replace the source database name in
each physical filename, preserving extensions and suffixes. If it is absent,
prefix the destination database name and an underscore. Directory names are not
renamed, and logical file names remain unchanged. Filename suffixes retain their
case: `AAA_data.mdf` becomes `BBB_data.mdf`, while `xyz.ndf` becomes `BBB_xyz.ndf`.
When the database name is unchanged, retain the physical basename and still
apply the folder policy to new files.

File lists are inspected in restore order. The full restore receives MOVE clauses
for its initial files. A differential or log restore receives MOVE clauses only
for files introduced at that step; future files are never included in the full
restore's mappings, and existing files are not relocated by later steps. For
example, a log that introduces `vvv.ndf` can create `BBB_vvv.ndf` in DataFolder.
The introducing backup's source database name controls the rename rule.

Preview's file-mapping result includes AddedOrdinal: 0 means an existing
continuation file; a positive value identifies the restore command introducing
that file. All planned destinations are checked for collisions before execution.
Only ordinary ROWS and LOG files are supported. File removal, file-ID/GUID reuse,
logical-file identity changes and FILESTREAM/container layouts require an explicit
restore sequence. A new file's creation LSN must be present and lie within the
log backup interval before a RESTORE LOG MOVE can be planned. Native RESTORE
also validates the operation. Restored file and undo paths are limited to 260 characters.

## Extra restore options and readable SQL

OtherRestoreOptions supplies additional WITH options for FULL, DIFF and LOG media
commands. Its default is `stats = 1`. Supplying NULL or ASCII whitespace omits
extras; a custom list replaces the default, so include STATS explicitly if wanted:

```sql
exec z.usp_RestoreDatabase
	@BackupPath = N'D:\Backups\Sales',
	@TargetDatabaseName = N'Sales_Test',
	@OtherRestoreOptions = N'stats = 5, checksum, buffercount = 8',
	@ShowPlan = 1;
```

Use comma-separated flags or `option = literal`. Values may be numeric,
hexadecimal, quoted strings (including N-prefixed strings and quoted commas/JSON),
or one keyword. Duplicate options use the last occurrence; opposing checksum,
error-handling, rewind/unload and broker switches share their option group.
Comments, statement separators outside quoted strings, expressions and stacked
SQL statements are rejected. SQL Server validates option availability and values.
RESTART can be supplied when its native resume requirements are met.

The planner owns FILE, MOVE, REPLACE, recovery/standby and point-in-time settings,
partial/filegroup selection and restricted-user access. Those cannot be overridden
through OtherRestoreOptions. Extras do not apply to HEADERONLY/FILELISTONLY/LABELONLY
or the separate final RECOVERY/STANDBY command.

Generated media SQL has one RESTORE/FROM line, one line per MOVE and one line for
the remaining options, for example:

```sql
restore database [Sales_Test] from disk = N'D:\Backups\Sales.bak'
with move N'Sales' to N'E:\Data\Sales_Test.mdf',
	move N'Sales_log' to N'F:\Log\Sales_Test_log.ldf',
	file = 1, norecovery, stats = 1;
```

Final RECOVERY and STANDBY commands remain one line. Command output uses
z.usp_PrintString, which emits long text in ordered chunks instead of truncating
one long PRINT message. Preview retains the full command in its nvarchar(max)
Command column.

## Recovery and standby

All backup-media commands use NORECOVERY. A separate final command applies
RECOVERY or STANDBY; the default NORECOVERY needs no finalization. RECOVERY brings
the database online; STANDBY makes it readable between restores. These options do
not change its recovery model. STANDBY cannot perform a database-version upgrade.

StandbyFolder is an optional directory. If null, use the primary data file's actual
destination directory. Use the selected full backup's filename, replacing its
extension with `.standby`; the destination database rename does not change this
undo filename. For example, `Sales_FULL_20261106.bak` produces
`Sales_FULL_20261106.standby` alongside the restored primary data file.

For a standalone log continuation, the full-backup filename must be recoverable
from trusted restore history; otherwise provide the full backup folder. SQL Server
consumes the previous undo file internally before applying another restore. The
final STANDBY command writes the new undo file at the resolved path; the procedure
does not search for or delete the previous file itself. Before writing the new
undo file, it checks that the output path is absent after the previous restore
has consumed the old undo file. A conflicting existing file stops finalization;
completed media restores remain NORECOVERY. An already-standby destination with
no pending logs and requested STANDBY is left unchanged, preserving its current
undo file. Preserve existing undo files between calls. StandbyFolder is ignored for
other recovery types.

## Preview and examples

ShowPlan = 1 reads backup/catalog metadata and returns the restore commands,
file mappings and a discovery summary without executing restores, creating
folders or changing databases. The summary identifies the source database/family,
DiscoveryMode (FILENAME or HEADER), FilesDiscovered and HeadersRead. HeadersRead
counts header-reader calls, not label reads or file-list reads.
It is a plan for the current inventory and destination state, not a reservation or
a guarantee that later native restore commands will succeed. For an existing
standby database, the final undo-path check can only complete after execution
consumes the old undo file; preview does not consume it. Native permissions,
backup availability, encryption keys, disk capacity and exclusive access remain
required. Run calls sequentially for destinations sharing database names or paths;
the preview does not reserve database names, media or output files.

```sql
-- Preview a renamed database with independent destinations.
exec z.usp_RestoreDatabase
	@BackupPath = N'D:\Backups\Production\MSSQLSERVER\Sales',
	@TargetDatabaseName = N'Sales_Test',
	@DataFolder = N'E:\Data',
	@LogFolder = N'F:\Log',
	@ShowPlan = 1;

-- Default: source name, replacement enabled, leave NORECOVERY.
exec z.usp_RestoreDatabase
	@BackupPath = N'D:\Backups\Sales';

-- Replace an in-use database after disconnecting its user sessions.
exec z.usp_RestoreDatabase
	@BackupPath = N'D:\Backups\Sales',
	@TargetDatabaseName = N'Sales_Test',
	@DropConnections = 1,
	@RecoveryType = 'RECOVERY';

-- Continue matching logs, then leave a readable standby database.
exec z.usp_RestoreDatabase
	@BackupPath = N'D:\Backups\Sales',
	@TargetDatabaseName = N'Sales_Test',
	@RecoveryType = 'STANDBY';

-- Preview one remote full backup; no remote folder discovery occurs.
exec z.usp_RestoreDatabase
	@BackupPath = N'https://example.blob.core.windows.net/backups/Sales.bak',
	@TargetDatabaseName = N'Sales_Test',
	@ShowPlan = 1;
```

SQL Server 2019 or later and database compatibility level 130 or higher are
required by the shared metadata readers/JSON decoders. Metadata inspection does
not verify all backup pages. Newer-engine backups cannot be made restorable on
older engines by this wrapper. See Microsoft's [restore sequences](https://learn.microsoft.com/en-us/sql/relational-databases/backup-restore/plan-and-perform-restore-sequences-full-recovery-model)
and [RESTORE arguments](https://learn.microsoft.com/en-us/sql/t-sql/statements/restore-statements-arguments-transact-sql).
