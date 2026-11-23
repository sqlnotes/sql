# Schema Z

Schema Z helps you maintain SQL Server databases: schedule jobs, manage
partitions, collect diagnostics, back up and restore databases, and run work in
parallel. It also provides shared SQL helpers for text, dates, metadata and
coordination. Install it in a database and call its objects through schema `z`.

Start with the [System developer guide](z/System/docs/readme.md). It links to
shared utilities, object references, and the eight feature subsystems:

- [Partition](z/System/010-Partition/docs/readme.md): boundaries and retention.
- [Monitoring](z/System/020-Monitoring/docs/readme.md): sessions, diagnostic trace presets and resource information.
- [Trace](z/System/010-Trace/docs/readme.md): SQL Trace configuration and collection.
- [Jobs](z/System/010-Jobs/docs/readme.md): SQL Agent jobs and schedule helpers.
- [Backup](z/System/020-Backup/docs/readme.md): sequential or parallel backups, restore planning, retention and snapshots.
- [Security](z/System/010-Security/docs/readme.md): permission generators and user utilities.
- [TaskQueue](z/System/012-TaskQueue/docs/readme.md): task batches, workers and recovery.
- [AsyncChannel](z/System/050-AsyncChannel/docs/readme.md): asynchronous data delivery and processing.

Use PowerShell 7 and SQL Server 2019 or later. Installation and repeat deployment create or reconcile the hourly maintenance job and clean up eligible orphan schedules in msdb. Use `-ShowPlan` to preview files before connecting. [Install and update](z/docs/deploy.md)

For deployment mechanics and authoring scripts, see the
[deployment developer guide](z/docs/readme.md).
