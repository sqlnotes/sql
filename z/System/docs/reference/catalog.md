# Catalog views and baseline objects

[Object index](readme.md)

## z.SeqGeneralID

[Source](../../baseline/1010%20Sequences/z.SeqGeneralID.sql). Int sequence: start/min 1, increment 1, max 268435455, cycle, cache 268435455. Used as the low 28-bit component of System IDs. Sequence consumption needs appropriate sequence access and is not rolled back; cache loss/restarts can create gaps. Cycling means reuse is possible.

## z.DatabaseSchemas

[Source](../../baseline/2020%20Tables/z.DatabaseSchemas.sql). One column `SchemaName nvarchar(128) not null`, primary key `PK_z_DatabaseSchemas`. It is a configuration list, without a foreign key to `sys.schemas`. Untargeted naming enforcement selects schemas listed here; initialization inserts `z`. Reads/writes require ordinary table permissions.

## Catalog views

All views are read-only projections over SQL Server catalogs; they do not create transactions. Caller metadata visibility governs completeness. Object IDs are current-database IDs, not portable identifiers. Raw column-name fields (`ColumnName`, `ParentColumnName`, `PartitionKeyName` and `PartitionKey`) retain catalog values for comparisons; apply `quotename()` when using them in generated SQL. SQL fragments (`IndexColumns`, `IndexColumnDefinition`, `IncludedColumns`, `PartitionColumn`, `ParentColumns` and `ReferencedColumns`) already delimit column identifiers, including reserved words, spaces and embedded closing brackets. For example, a partition column named `Key` yields `([Key])` in `PartitionColumn`.

| Object and source | Row meaning and important outputs |
| --- | --- |
| [z.v_Objects](../../modules/1020%20Views/z.v_Objects.sql) | One column per catalog object. ObjectID, SchemaName, ObjectName, ObjectType, ColumnID/ColumnName, PrimaryKeyOrder, type/length/nullability/collation, ReadOnly, identity/computed/rowversion flags, computed definition and identity seed/increment/current value |
| [z.v_Indexes](../../modules/1020%20Views/z.v_Indexes.sql) | One nonheap index on a user table/view. ObjectID/IndexID, names/expected name, IndexType, primary/unique flags, ordered key definition, included/filter definitions, storage/partition key, compression and index options/XML parent |
| [z.v_DefaultConstraints](../../modules/1020%20Views/z.v_DefaultConstraints.sql) | One default: ObjectID, SchemaName, DefaultName/ExpectedDefaultName, ParentObjectID/ParentColumnID, parent names, Definition, IsSystemNamed |
| [z.v_CheckConstraints](../../modules/1020%20Views/z.v_CheckConstraints.sql) | One check: ObjectID, SchemaName, CheckConstraintName, ParentObjectID/ParentObjectName/ParentColumnName, Definition, IsDisabled, IsSystemNamed, IsNotTrusted |
| [z.v_ForeignKeys](../../modules/1020%20Views/z.v_ForeignKeys.sql) | One FK: IDs/names/expected name, parent/referenced schema/table, ParentColumns/ReferencedColumns, DeleteAction/UpdateAction, named/disabled/trusted flags |
| [z.v_PartitionedIndexes](../../modules/1020%20Views/z.v_PartitionedIndexes.sql) | One partitioned heap/index partition: ObjectID/IndexID, names, PartitionNumber/Rows, PartitionKeyName, DataSpaceID/scheme/filegroup, function ID/name, BoundaryValueOnRight, boundary ID/value/type/date, TotalPartitions, DataCompression, PartitionKey |

`z.v_Indexes` depends on `z.fn_GetExpectedName`. It directly reads `sys.indexes.optimize_for_sequential_key`, supported by the SQL Server 2019 (15.x) minimum. Key/include fragments use `nvarchar(max)` to preserve Unicode identifiers. `Compression` summarizes only rowstore compression: PAGE if any index partition uses PAGE, otherwise ROW if any uses ROW, otherwise NULL. NONE and columnstore/archive compression are not reported here; this is not a per-partition map. `z.v_DefaultConstraints`/`z.v_ForeignKeys` also use expected-name generation.

`z.v_PartitionedIndexes.DataCompression` is the per-partition catalog compression description (`NONE`, `ROW`, `PAGE`, `COLUMNSTORE`, or `COLUMNSTORE_ARCHIVE`). `PartitionKey` is the raw partitioning column name, matching the retained `PartitionKeyName` column. Table names are returned as `ObjectName`; there is no separate `TableName` alias. `BoundaryDateValue` is `datetime`, retaining the converted time component; bigint boundaries follow the Z sequence ID decoding rule in `z.fn_SqlVariantToDateTime`.

`z.v_PartitionedIndexes` depends on `z.fn_SqlVariantToDateTime`. It associates boundary ID with `PartitionNumber - 1` irrespective of direction; the first partition has no associated boundary. Its allocation-unit/filegroup query is a selected summary and need not describe all allocation types. Do not infer exact switch eligibility from this view alone.
