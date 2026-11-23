# z.usp_CreateDatabaseSnapshot

[Backup](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_CreateDatabaseSnapshot.sql)

## Purpose and behavior

Creates a native SQL Server database snapshot: a read-only view of the source database at creation time. Use it when you need to query a stable copy while the source continues to change. It creates sparse snapshot files beside the source data files; it does not create a backup or restore the source.

## Parameters and defaults

```text
@SourceDatabaseName nvarchar(128) = null,
@DatabaseSnapshotName nvarchar(128) = null
```

Omit `@SourceDatabaseName` to snapshot the current database. Omit `@DatabaseSnapshotName` to use `<source>_Snapshot`. An unknown source or an already-existing snapshot name causes an error. Each sparse filename appends a dot and the snapshot name, with spaces removed, to its source data-file path.

## Results, permissions, and limits

Creates the named snapshot without returning rows. Requires native snapshot creation permissions, a supported source/edition, and SQL Server service-account storage access. It does not delete snapshots or implement restore/revert. Errors propagate; the procedure does not wrap its work in an explicit transaction.

## Dependencies

Native dependencies: `sys.database_files`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
