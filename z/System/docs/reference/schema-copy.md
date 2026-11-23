# Schema copy

[Object index](readme.md)

Use `z.usp_CopyTableSchema` to create an empty table with the columns, supported indexes and defaults of an existing table. It is useful when preparing a destination for a partition switch or recreating a table structure. It copies definitions, not data. Preview with `@ShowPlan = 1` before applying the generated statements.

## Interfaces

`z.usp_CopyTableSchema` generates and executes the schema-copy statements. With `@ShowPlan = 1`, it instead returns `Ordinal int`, `PartName varchar(30)` and `Definition nvarchar(max)` rows in execution order without executing generated SQL. [Procedure declaration](procedures.md#zusp_copytableschema).

## Inputs

Supply `@FullSourceTableName` and `@FullTargetTableName` as schema-qualified names in the current database, for example `dbo.Source` and `dbo.Archive`. The [declaration](procedures.md#zusp_copytableschema) lists exact types and defaults.

| Parameter or group | How to use it |
| --- | --- |
| `@PartitionNumber` | Select the source partition whose placement and compression should be copied. Omitted or NULL means partition 1; a nonpartitioned source accepts only 1. |
| `@ShowPlan` | Set to 1 to return ordered script rows without executing them. |
| `@DropTargetTableIfExists` | Set to 1 only when the existing target may be dropped and replaced. The default protects it. |
| `@CopyIdentity`, `@CopyTableSchema`, `@CopyIndexes`, `@CopyXMLIndexes`, `@CopyDefault` | Choose which definitions to copy. All default to 1. Disabling table creation requires an existing target. |
| `@FileGroupOrPartitionScheme`, `@DataCompression` | Leave NULL to inherit the selected source storage and compression, or supply explicit overrides. |
| `@ScriptAfterTableCreation` | Optional trusted SQL to run after creating the table, before indexes and defaults. |
| `@PrintCode` | Print generated SQL while executing it. Use `@ShowPlan` for a preview that makes no changes. |

Storage null inherits each heap/index filegroup separately. For a partitioned source, the filegroup is the destination mapped to that index's selected partition. Compression null similarly inherits each selected heap/index partition's compression, including NONE, ROW, PAGE, COLUMNSTORE and COLUMNSTORE_ARCHIVE where applicable. Empty partitions do not need allocated pages for storage resolution.

An explicit `@FileGroupOrPartitionScheme` overrides placement; an explicit `@DataCompression` overrides compression. A partition-scheme override creates a partitioned target, an exception to the normal nonpartitioned target. Overrides can prevent partition switching when they differ from the source partition's storage or compression. Validation checks every source index type before applying copy flags, including categories excluded from execution. A compression override must be supported by all of them; XML indexes accept only NONE even when XML copying is disabled.

For partition switch-out, leave both overrides null and pass the partition being switched:

```sql
exec z.usp_CopyTableSchema
	@FullSourceTableName = N'dbo.Source',
	@FullTargetTableName = N'dbo.SourceArchive',
	@PartitionNumber = 2;
alter table dbo.Source switch partition 2 to dbo.SourceArchive;
```

The former `z.fn_BuildQueryCopyTableSchema` is retired by System deployment. Replace script-generation calls with this procedure and `@ShowPlan = 1`. The new parameter is appended after `@PartitionNumber`; existing procedure parameters retain their positions. Replacement requires an explicit `@DropTargetTableIfExists = 1`.

## Effects, permissions and transactions

In execution mode, the procedure creates an empty table; it copies definitions, not rows, and does not perform the switch. Existing targets are rejected unless replacement is explicitly requested. Source metadata, overrides and target conditions are validated with direct errors before replacement.

Preview mode permits an existing target when reviewing a new table definition. Copy flags filter the returned statements exactly as they do for execution. When replacement is requested and a target exists, the preview includes its DROP statement first. Preview does not drop/create targets, run after-table SQL, invoke the printer, or begin/save/commit a transaction. `@ShowPlan = 1` takes precedence over `@PrintCode`. Invalid source metadata or overrides still raise errors. `@CopyTableSchema = 0` still requires an existing target.

The procedure temporarily disables implicit transactions while generating scripts and restores the caller's setting on return. DDL uses an explicit transaction. The procedure commits only a transaction it started; inside an existing transaction it uses a savepoint. A committable failure rolls back its own work. An uncommittable caller transaction must be rolled back by the caller. Printing generated code still executes it.

Permissions must cover source metadata, schema/table/index DDL and caller-provided SQL. SQL fragments must be trusted. Concurrent source DDL is not serialized.

## Dependencies and limitations

Column identifiers are quoted, preserving reserved keywords, spaces, Unicode and embedded closing brackets. For example, a column named `order` is scripted as `[order]`, and `A]B` as `[A]]B]`. Index keys/includes, XML fields, partition keys and default-column references use the same quoting; computed and filter expressions retain their stored SQL definitions.

Copies columns, supported indexes and defaults with target-based names. Column metadata includes original identity seed/increment when enabled, collation, schema-qualified types and computed expressions/persistence. Copying identity metadata does not reseed an empty target to the source's current identity value. Foreign keys, CHECK constraints, triggers, permissions and extended properties are excluded.

The table, ordinary/columnstore indexes, XML indexes and defaults flags select distinct script categories. After-table SQL runs immediately after table creation and before index/default definitions. Supported SQL Server versions start at 2019 (15.x); sequential-key options are emitted for ordinary rowstore indexes and key constraints.

Unsupported sources are rejected before target changes: memory-optimized, temporal, graph and FILESTREAM tables; sparse, generated, hidden, encrypted or masked columns; full-text, spatial/hash/JSON, selective XML, ordered/data-clustered columnstore indexes and enabled XML compression; legacy ANSI_PADDING OFF columns and standalone bound defaults. Disabled/hypothetical indexes and nonaligned partitioning, including an ordinary base table with partitioned secondary indexes, are also rejected. Supported copy metadata is not a guarantee that every source can be switched: source constraints, indexed views and other engine restrictions can still prevent a switch. Check the engine's SWITCH requirements and test the intended operation.
