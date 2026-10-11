# Schema copy

[Object index](readme.md)

## Interfaces

`z.fn_BuildQueryCopyTableSchema` returns `Ordinal`, `PartName`, `Definition` rows. `z.usp_CopyTableSchema` executes them. [Function declaration](functions.md#zfn_buildquerycopytableschema) · [Procedure declaration](procedures.md#zusp_copytableschema).

## Inputs

The procedure requires source/target names (`nvarchar(256)`). Optional defaults: storage null; drop-existing target 1; copy identity/table/indexes/XML/defaults each 1; after-table SQL null; compression null; print 0. Use two-part names.

Storage null selects a source allocation filegroup. `Use Source Object Partition Scheme` and `Use default Database File Group` select those placements. A named filegroup or `PartitionScheme(Column)` is also accepted. Unresolvable metadata can produce no definitions and `Could not retrieve script.`

## Effects, permissions and transactions

The procedure drops an existing target by default and creates an empty table. It copies definitions, not data. It uses `nocount`/`xact_abort`, begins a transaction, commits on success and rolls back any open transaction on error, including caller work.

Permissions must cover source metadata, schema/table/index DDL and caller-provided SQL. SQL fragments must be trusted. Concurrent source DDL is not serialized.

## Dependencies and limitations

Depends on shared object/index/default/partition views, expected-name function and printer. Foreign keys, checks, triggers, permissions and extended properties are excluded. Identity becomes `(1,1)`. Compression is summarized instead of preserved per partition.

Flags overlap: the indexes branch includes the table definition. Print still executes. After-table SQL shares ordinal 10000 with table creation, so ties have no deterministic order guarantee. Generated sequential-key index options require SQL Server 2019+.
