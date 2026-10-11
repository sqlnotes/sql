# z.usp_CreateDatabaseSnapshot

[Backup](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_CreateDatabaseSnapshot.sql)

## Purpose and behavior

Resolve null source to the current database; default snapshot name is <source>_Snapshot. Reject an unknown source or existing target. Read data-file logical names/paths through source-database sp_executesql and issue CREATE DATABASE AS SNAPSHOT OF. Sparse filenames append a dot and the snapshot name with spaces removed to each source path. Uses xact_abort; no explicit transaction or catch.

## Parameters and defaults

```text
@SourceDatabaseName nvarchar(128) = null,@DatabaseSnapshotName nvarchar(128) = null
```

These are the source-declared types and defaults.

## Results, permissions, and limits

No defined result set. Requires native snapshot creation permissions, supported source/edition, and service-account storage access. It does not delete snapshots or implement restore/revert.

## Dependencies

Native dependencies: `sys.database_files`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
