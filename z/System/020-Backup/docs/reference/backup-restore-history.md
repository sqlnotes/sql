# Backup and restore inspection

[Object index](readme.md) | [Subsystem](../readme.md)

Use `z.BackupRestoreHistory` to inspect local execution outcomes from `z.usp_BackupDatabase` and `z.usp_RestoreDatabase` without querying `msdb`. Use the read-only `msdb` and DMV views when you need full backup-set LSN metadata, external backups not run through these procedures, or live progress of an active native command.

## z.BackupRestoreHistory

[Source](../../baseline/2020%20Tables/z.BackupRestoreHistory.sql)

Partition-managed execution log for backups and restores run through this subsystem. Each backup step (`FULL`, `DIFF`, `LOG`) and each executed restore step (`FULL`, `DIFF`, `LOG`, `FINALIZE`) or planning/inventory failure writes one row with a run `BatchID` (`uniqueidentifier` shared across all databases in a sequential or multi-threaded `z.usp_BackupDatabase` call, or per `z.usp_RestoreDatabase` call), UTC `StartTime`, `EndTime`, `DurationMs`, `Status` (`Succeeded` or `Failed`), `BackupFile`, `ErrorNumber`, `ErrorMessage`, and session context (`LoginName`, `ApplicationName`, `HostName`, `SessionID`). For backups, `IsCopyOnly` reflects `@CopyOnly = 1` and automatic read-only `COPY_ONLY` on `FULL` and `LOG` steps (top-level `COPY_ONLY` supplied in `@OtherBackupOptions` is stripped). `@ShowPlan = 1` previews do not write rows.

`HistoryID` uses the shared UTC-prefixed sequence identifier (`datediff_big(second, '19000101', getutcdate()) * 268435456 | next value for z.SeqGeneralID`) clustered on `PS_SchemaZPartitionGeneric(HistoryID)` with `DATA_COMPRESSION = ROW` and no secondary indexes, keeping high-database-count logging lightweight and automatically truncated by [Partition](../../../010-Partition/docs/readme.md) maintenance.

When runtime native `BACKUP` or `RESTORE` execution fails inside T-SQL `TRY...CATCH`, SQL Server exposes the terminating `3013` error to `ERROR_NUMBER()` and `ERROR_MESSAGE()` (`BACKUP DATABASE is terminating abnormally.`, etc.); check the SQL Server error log for underlying operating-system or media error messages. Compile or option-syntax failures (such as an invalid `@OtherBackupOptions` clause) record their direct SQL error (such as `155`), and procedure-level validation and planning errors record their specific `50000` message directly.

```sql
select top (100)
	HistoryID, BatchID, Operation, DatabaseName, SourceDatabaseName,
	BackupType, RecoveryType, IsCopyOnly, Status, DurationMs,
	StartTime, EndTime, ErrorNumber, ErrorMessage, BackupFile,
	LoginName, ApplicationName, HostName, SessionID
from z.BackupRestoreHistory
order by HistoryID desc;
```

## msdb and DMV views

These read-only views expose recorded `msdb` history and active requests. They do not
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
