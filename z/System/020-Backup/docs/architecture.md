# Backup architecture

[Subsystem](readme.md) | [Object index](reference/readme.md)

## Installation and dependencies

The subsystem installs in System's alphabetical child order. Shared System modules precede feature children; System post scripts follow them. See [System documentation](../../docs/readme.md).

Uses server catalogs, msdb backup history, filesystem operations and native backup/create-database commands. Filesystem destinations need SQL Server service-account access; URL destinations need configured SQL Server credentials and storage permissions. Windows supports local folders and UNC shares; Linux uses local or mounted filesystem paths.

## Backup flow

`z.usp_BackupDatabase` resolves a database list and processes it once, sequentially by data-file size. For each database it creates a directory for filesystem destinations only, then performs native BACKUP TO DISK or BACKUP TO URL. A native backup error stops the call; previous files remain. New calls start fresh. Parallel jobs, shared assignments and persistent backup status are unsupported.

The backup procedure has no application lock. The cleanup helper locks only while cleaning up; it does not coordinate with active backups. Schedule standalone cleanup separately from backups.

Stop existing backup workers before upgrading. System post cleanup removes the retired status view and trigger. Old backup extended properties are no longer used or maintained; their presence does not affect execution.

## Destinations, retention and reporting

Azure HTTPS and S3 URLs use forward slashes on either operating system and retain their case. URL destinations skip filesystem operations. ServerName defaults to @@servername and only controls the naming prefix. Storage credentials and containers/buckets must already exist. S3 requires SQL Server 2022 or later.

Retention is never called by the backup procedure. `z.usp_CleanupDatabaseBackups` inventories files in the selected database's FULL, DIFF and LOG folders. Filename mode uses recognized six-digit timestamp names without opening headers; optional header mode supports irregular filenames and metadata dependency checks. Unrecognized names are preserved in filename mode. Neither mode guarantees complete recovery coverage. See [cleanup reference](reference/z.usp_CleanupDatabaseBackups.md).

`z.v_BackupRestore` reads msdb reporting history independently; that history does not choose deletion candidates. `z.usp_CreateDatabaseSnapshot` is separate from retention. The parameterless Full/Log wrappers use a fixed UNC destination; inspect them before use.
