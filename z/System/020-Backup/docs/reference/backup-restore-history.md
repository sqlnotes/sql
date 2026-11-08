# Backup and restore inspection

[Object index](readme.md) | [Subsystem](../readme.md)

These read-only views expose recorded history and active requests. They do not
open backup media or certify that a restore chain is complete. History reflects
the local instance's retained msdb records; backups copied from another server
may have no record here. Cleaning msdb history removes those observations.

Columns put database names, operation details, times, sizes and progress first.
Login names, diagnostic metadata, IDs and GUIDs appear toward the end.

Readable durations use z.fn_FormatDurationMilliseconds with `days hh:mm:ss.fff`
format, alongside existing numeric time columns. Backup history exposes Duration;
restore history exposes BackupDuration for the source backup (msdb does not record
restore completion time). Active requests expose ElapsedDuration,
EstimatedRemainingDuration, WaitDuration and CpuDuration. Estimates remain native
diagnostic estimates.

## z.v_BackupHistory

[Source](../../modules/1020%20Views/z.v_BackupHistory.sql)

One row per backup set, including source database, backup type, start/finish time,
duration, sizes, copy-only flag, LSN range, checkpoint, differential base and
database family/recovery-fork identifiers. Media locations are aggregated to
preserve this row count. A recorded path does not prove that the file still exists.

## z.v_RestoreHistory

[Source](../../modules/1020%20Views/z.v_RestoreHistory.sql)

One row per recorded restore operation, with destination/source names, restore
type, recovery/replacement options, stop-at settings and backup metadata. History
is retained even when the corresponding backup-set row is unavailable. A restore
timestamp is the recorded operation start, not a measured completion time.
Rows belonging to a reused database name do not prove the current database's
identity or restore position.

## z.v_BackupRestoreRequests

[Source](../../modules/1020%20Views/z.v_BackupRestoreRequests.sql)

One row per visible active backup/restore request, including session/request IDs,
command, execution database context, percent complete, elapsed time, estimated
remaining milliseconds, waits and SQL text. The execution context may be master
or the helper database; it is not an inferred restore destination. Progress is
for the current native command, rather than the entire restore sequence.
Estimated completion time is a diagnostic estimate and may be zero or inaccurate.
No row means no visible active request, not that an operation succeeded.

Access requires permissions on the underlying msdb tables and server DMVs.
Viewing other sessions normally requires VIEW SERVER STATE on SQL Server 2019
and VIEW SERVER PERFORMANCE STATE on SQL Server 2022 or later. The views do not
grant these permissions. SQL text and media paths can contain sensitive values;
grant access accordingly.

```sql
select * from z.v_BackupHistory
where DatabaseName = N'Application'
order by BackupFinishDate desc, BackupSetID desc;

select * from z.v_RestoreHistory
where DestinationDatabaseName = N'Application_Test'
order by RestoreHistoryID desc;

select * from z.v_BackupRestoreRequests;
```

The existing [z.v_BackupRestore](supporting-objects.md#zv_backuprestore)
remains available for combined media/restore detail. Unlike these history views,
that join can return several rows per backup set.

System references: [backupset](https://learn.microsoft.com/en-us/sql/relational-databases/system-tables/backupset-transact-sql),
[restorehistory](https://learn.microsoft.com/en-us/sql/relational-databases/system-tables/restorehistory-transact-sql)
and [sys.dm_exec_requests](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-requests-transact-sql).
