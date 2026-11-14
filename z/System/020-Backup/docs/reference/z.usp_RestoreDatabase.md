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
	@OtherRestoreOptions nvarchar(max) = N'stats = 10',
	@DataFolder nvarchar(4000) = null,
	@LogFolder nvarchar(4000) = null,
	@StandbyFolder nvarchar(4000) = null,
	@UseDefaultFolder bit = 1,
	@ShowPlan bit = 0,
	@DropConnections bit = 1
)
```

## Source selection

A local folder is searched recursively. A file or HTTP(S)/S3 URL considers only
that object; remote folders and sibling objects are not enumerated. Recognized
filenames are decoded and grouped by server, instance and database labels, with
newest timestamps inspected first. The naming convention is trusted for grouping
and chronological file order. Read older headers only until a complete chain is
proven from a full backup or the destination's current restore position.
Each inspected file is read once and all appended backup sets are cached.

Nonconforming filenames are inspected after the recognized groups. Their sets
are merged before final planning; recognized groups are revisited when the merged
inventory requires an older base or missing chain segment. Header family, fork,
backup type and LSNs validate the selected chain. Selected media labels and file
layouts are also validated. Unopened older files are not inspected for hidden
sources or newly appended sets: convention-compliant containers must retain their
source grouping and chronological ordering. A custom filename layout outside the
recognized convention uses header discovery.
Native URL credentials and transport support must already be configured.

A file may contain multiple appended backup sets. Each selected command uses its
`FILE = position`. Mixed sets in a file and equivalent sets in a folder follow
the same source-selection rules. Striped backups spanning several media files
remain unsupported; unrelated unsupported media is reported separately.

With TargetDatabaseName omitted, process each eligible user database family under
its source name. Initialize missing databases when a usable full is available;
defer sources containing only logs/differentials. Continue matching RESTORING or
STANDBY databases. Existing ONLINE and unavailable databases are skipped even when
ReplaceExisting = 1. The automatic path never replaces an existing database.
System database sources master, model, msdb and tempdb are skipped. The database
hosting this procedure cannot be restored.

One family is one source even when it has several full backups or source-name
aliases. Use the newest header name deterministically for a new target. If one
existing RESTORING/STANDBY database matches that family and a source-name alias,
continue that target after a source rename instead of creating another target.
Several existing matching aliases, or distinct families sharing a destination
name, are ambiguous and fail that source. If retained media no longer includes
the old source name but another same-family continuation database exists,
automatic creation fails conservatively; specify the intended target explicitly.

With an explicit missing target, exactly one usable full-backed source family
must exist. Multiple fulls of A count as one source. A full of A plus standalone
logs/differentials of B also counts as one initialization source. Fulls of A and
B are ambiguous and rejected, even when one source name matches the target.
The same unique-source rule applies to explicit replacement. For initialization
or replacement, the newest eligible full by completion time establishes the
supported recovery branch. Evaluate full starting points and matching differentials
on that branch to reach the greatest endpoint; prefer a log-only route on ties.
An older regular full plus a differential can therefore win over a newer copy-only
full when it restores farther. LSNs are never ranked across recovery branches. An existing
RESTORING/STANDBY target instead selects its native family/fork; unrelated
restorable databases do not make continuation ambiguous. Renamed targets work
the same way. A log or differential alone cannot create a missing database.

Plan the log-only route first, without executing any commands. Prefer it when it
reaches the latest eligible endpoint. Consider a matching differential only when
it reaches beyond that log-only endpoint; then plan its subsequent logs. A
copy-only full cannot be a differential base. A differential requires a proven
unrecovered full state with no intervening log restore; it is not a general gap
repair for an already advancing secondary. No gap causes an automatic full
reseed. An unbridgeable gap fails planning for that database before any of its
restore commands execute. LSNs are compared only within compatible families and
recovery branches; branch transitions remain unsupported.

Already-covered backups are skipped. Invalid pending log media that extends
beyond every usable route fails the affected database; a valid alternative that
covers its endpoint can still be used. Unreadable or unsupported inventory objects
are reported. Known foreign media errors do not prevent an explicit target from
using its own compatible backups. Unknown unreadable identities prevent proving
an unambiguous initialization/replacement source. A continuing target can process
its known compatible media, but unresolved inventory errors remain in the final
outcomes and cause an aggregate execution error.

All sources are discovered and every target plan is completed before the first
restore executes. The shared temporary plan stores the exact commands, backup-set
positions, execution order, file mappings and destination guards. Independent
sources retain separate outcomes; one source's failure does not stop other sources. The final outcomes identify DatabaseName, SourceDatabaseName,
SourceFamilyGUID, Status, LastLSN, ErrorNumber, ErrorMessage and BackupPath.
Statuses include Initialized, Advanced, AlreadyCurrent, Deferred, Skipped, Ignored
and Failed; successful previews use Planned. After returning outcomes, execution
throws an aggregate error if any source failed. Preview reports failures without
executing restores. Explicit-target errors remain errors. This is a sequential
restore operation, not a transaction across databases.

## Destination state and replacement

| Destination | Explicit target | Omitted target |
| --- | --- | --- |
| Missing | Initialize the unique full-backed source | Initialize each eligible source, defer those without a full |
| RESTORING or standby | Continue native matching identity/progress | Continue native matching identity/progress |
| Other state, ReplaceExisting = 1 | Replace from the unique full-backed source | Skip |
| Other state, ReplaceExisting = 0 | Error | Skip |

A RESTORING or STANDBY destination with available recovery identity is continued.
For an explicit target only, if its family or recovery fork is unavailable, ReplaceExisting = 1 instead plans
a replacement from the latest selected full, compatible differential and logs.
OFFLINE, SUSPECT and RECOVERY_PENDING destinations also require replacement.
ReplaceExisting = 0 rejects those replacements, and a full backup is required.
A known but incompatible family, fork or log chain still fails continuation.
Continuation reads the database family/fork from sys.database_recovery_status
and the current file identities, physical paths and next redo LSN/fork from
sys.master_files. Database name alone does not establish identity. Existing files
retain their current paths; pending backups are checked against those file
identities with FILELISTONLY. DataFolder/LogFolder apply to newly introduced files.
Ordinary log continuation does not need retained msdb restore history when native
recovery metadata is available.

A matching full header, its differential base and the current redo position can
establish differential eligibility. Otherwise, inspect a differential candidate before consulting the latest restore
record. An already-covered differential or a known incompatible native base does not
trigger a history lookup. A newer incompatible differential does not hide an older
compatible one. Missing or incompatible history disables an unproven
optional differential; compatible logs can still continue. An explicitly supplied
differential must have a proven matching base. Differential-base catalog fields
alone do not prove that no log has been restored since the full.

If native redo metadata is unavailable for a standby database, compatible retained
history supplies the fallback position. Undo-file naming does not require history.
An already-current standby performs no finalization.

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
commands. Its default is `stats = 10`. Supplying NULL or ASCII whitespace omits
extras; a custom list replaces the default, so include STATS explicitly if wanted:

```sql
exec z.usp_RestoreDatabase
	@BackupPath = N'D:\Backups\Sales',
	@TargetDatabaseName = N'Sales_Test',
	@OtherRestoreOptions = N'stats = 5, checksum, buffercount = 8',
	@ShowPlan = 1;
```

The supplied text is appended unchanged to the media command's WITH options.
The procedure does not parse, validate or deduplicate it. SQL Server decides
option validity on execution; duplicates may be accepted by the engine.
Use ShowPlan to inspect
the generated commands. Extras do not apply to HEADERONLY/FILELISTONLY/LABELONLY
or the separate final RECOVERY/STANDBY command.

Generated media SQL has one RESTORE/FROM line, one line per MOVE and one line for
the remaining options, for example:

```sql
restore database [Sales_Test] from disk = N'D:\Backups\Sales.bak'
with move N'Sales' to N'E:\Data\Sales_Test.mdf',
	move N'Sales_log' to N'F:\Log\Sales_Test_log.ldf',
	file = 1, norecovery, stats = 10;
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

StandbyFolder is the directory for the undo file. If NULL, use the primary data
file's actual destination directory. The basename is the standardized target
database name plus `.standby`, for example `Sales_Test.standby`. A renamed target
gets its own undo basename. This naming requires neither a full backup header nor
msdb history. SQL Server
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
folders or changing databases. Each per-target summary identifies the source database/family,
DiscoveryMode (FILENAME for recognized names, HEADER when nonconforming files
are present), FilesDiscovered and HeadersRead. Automatic preview returns
per-target plans and mappings followed by the combined outcomes. HeadersRead
counts shared inventory header-reader calls, not label reads or file-list reads.
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

-- Automatic discovery: source names, skip online targets, leave NORECOVERY.
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
