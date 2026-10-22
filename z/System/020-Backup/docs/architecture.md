# Backup architecture

[Subsystem](readme.md) | [Object index](reference/readme.md)

## Dependencies and installation

Uses sys.databases, sys.master_files, msdb backup history, filesystem extended procedures, and native backup/create database commands. Requires server-local or UNC storage accessible to the SQL Server service account.

The numbered folder installs in System's alphabetical child order. Shared System modules run before feature children; System post scripts run after all children. See [System documentation](../../docs/readme.md) for deployment and orchestration. Baseline tables use existence guards; they do not reconcile an existing table schema. Module definitions use create or alter.

## Data and control flow

`z.usp_BackupDatabase` selects databases from server catalogs, creates destination directories, executes a native backup per database, then calls `z.usp_CleanupDatabaseBackups`. Cleanup inventories actual files in that database's FULL, DIFF and LOG folders. The default mode parses managed filenames without header reads; optional `UseBackupHeader = 1` reads native labels and headers for irregular filenames and dependency checks. `msdb` history remains the reporting source for `z.v_BackupRestore`; it does not determine deletion candidates. The Full/Log wrappers supply fixed operational settings. `z.usp_CreateDatabaseSnapshot` is independent of backup retention and does not provide a restore operation.

Filename mode retains the latest recognized full timestamp at or before the cutoff, newer recognized backups and the preceding log, and preserves unrecognized names. Header mode selects an ordinary full anchor using backup metadata, preserves overlapping logs and verifies retained differential bases; ambiguous media prevents deletion for the whole inventory. Neither mode establishes complete recovery coverage. Filename mode additionally trusts naming and cannot establish actual backup identity, copy-only status or dependencies. See the [cleanup reference](reference/z.usp_CleanupDatabaseBackups.md) for both modes and preview behavior.

Windows uses local paths or UNC shares; Linux uses absolute paths to local or mounted storage. The parameterless Full/Log wrappers contain a fixed UNC destination; inspect them before use.

Each callable reference describes writes, generated SQL, transaction boundaries, results and inputs. Supporting references describe keys, payloads and units. Procedures do not supply a blanket permission grant or one transaction around an entire administrative workflow.

## Integration constraints

`z.v_DatabaseBackupStatus` joins visible server databases and FULL/DIFF/LOG types to central status properties. Its `INSTEAD OF UPDATE` trigger persists one JSON record per database/type for registration, claiming and completion. Catalog identity and BackupType are read-only; missing, invalid or stale properties cannot hide a database/type row. View writes use the registration gate with transaction ownership, held until the caller commits. `z.usp_BackupDatabase` uses the same transaction-owned gate for short registration and status updates. See the [status reference](reference/z.v_DatabaseBackupStatus.md).

Parallel callers share assignments through database-level extended properties in the database containing the procedures. RunID hashes the sorted resolved database names; `(RunID, BackupType)` identifies participating workers. The first worker initializes a batch, joiners preserve its flags, and each session claims available unfinished databases. Busy databases are skipped while other work is available. Workers retry while assignments remain unfinished and exit after completion or supersession. A call after all participants exit starts a fresh batch.

For each database, FULL and DIFF share an exclusive DATA execution lock, while LOG has a separate exclusive LOG lock. Both lanes hold shared folder locks during native backup. Cleanup requires an exclusive folder reservation after releasing the shared lock; if another backup is active, cleanup is deferred. A later backup or separate cleanup call must obtain another retention opportunity.

| Existing operation | New FULL | New DIFF | New LOG |
| --- | --- | --- | --- |
| FULL | Wait | Wait | Allow |
| DIFF | Wait | Wait | Allow |
| LOG | Allow | Allow | Wait |

Later different sets replace overlapping assignments only within the same backup type, without canceling active native backups. Completion checks prevent an older session from completing a newer assignment. All workers must use the same coordination database and matching settings within their run/type. See the [backup reference](reference/z.usp_BackupDatabase.md) for recovery and cancellation requirements.

Stop existing workers before upgrading from untyped status to this model. Old properties cannot establish their backup type, and old/new execution lock names are incompatible. Install the view, procedure and trigger together, then initialize fresh typed batches; legacy properties remain ignored.

Unknown or ineligible database names can lead to No databases to be backup rather than an error. Offline databases and database snapshots are not explicitly excluded by the selection query and can fail at native BACKUP execution. A null backup folder falls back to InstanceDefaultBackupPath, which may be unavailable on some target versions. Filesystem permissions belong to the SQL Server service account. The snapshot procedure stores physical_name in sysname (128 characters) and does not escape single quotes in generated filenames; long or quoted paths can fail.
