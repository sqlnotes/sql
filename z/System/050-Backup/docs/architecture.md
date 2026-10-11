# Backup architecture

[Subsystem](readme.md) | [Object index](reference/readme.md)

## Dependencies and installation

Uses sys.databases, sys.master_files, msdb backup history, filesystem extended procedures, and native backup/create database commands. Requires server-local or UNC storage accessible to the SQL Server service account.

The numbered folder installs in System's alphabetical child order. Shared System modules run before feature children; System post scripts run after all children. See [System documentation](../../docs/readme.md) for deployment and orchestration. Baseline tables use existence guards; they do not reconcile an existing table schema. Module definitions use create or alter.

## Data and control flow

`z.usp_BackupDatabase` selects databases from server catalogs, creates destination directories, executes a native backup per database, then scans msdb history for older files to delete. The Full/Log wrappers supply fixed operational settings. `z.v_BackupRestore` reads recorded backup/media/restore history independently of backup execution. `z.usp_CreateDatabaseSnapshot` reads source data-file paths and creates sparse snapshot files beside them; it is independent of backup retention and does not provide a restore operation.

Backup execution can delete earlier backup files. The retention scan is based on msdb history and is not restricted to the requested backup folder. The parameterless Full/Log wrappers contain a fixed UNC destination; inspect them before use.

Each callable reference describes writes, generated SQL, transaction boundaries, results and inputs. Supporting references describe keys, payloads and units. Procedures do not supply a blanket permission grant or one transaction around an entire administrative workflow.

## Integration constraints

Unknown or ineligible database names can lead to No databases to be backup rather than an error. Offline databases and database snapshots are not explicitly excluded by the selection query and can fail at native BACKUP execution. A null backup folder falls back to InstanceDefaultBackupPath, which may be unavailable on some target versions. Filesystem permissions belong to the SQL Server service account. The snapshot procedure stores physical_name in sysname (128 characters) and does not escape single quotes in generated filenames; long or quoted paths can fail.
