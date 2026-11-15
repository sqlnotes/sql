# System troubleshooting

[Guide](readme.md) · [Source-linked object reference](reference/readme.md)

## Compatibility

`z.v_Indexes` references `sys.indexes.optimize_for_sequential_key` and schema-copy emits that option. The minimum supported version is SQL Server 2019 (15.x), which supports these paths. Microsoft lists this column as available from SQL Server 2019 in its [sys.indexes reference](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-indexes-transact-sql?view=sql-server-ver17).

## Environment detection

`z.fn_IsAzureDatabase` returns 0 in both branches. `z.fn_IsHostedDatabase` therefore recognizes only the current Amazon RDS heuristic. Do not use either as an authoritative feature check.

## Naming errors

`z.usp_ForceNamingConvention` requires an explicit schema/table selector. Preview with `@ShowPlan = 1` before applying renames. `@IgnoreError = 0` stops on the first rename failure; `1` prints the error and continues with other candidates. Renaming is non-atomic, so completed changes may persist after a later failure. The procedure does not roll back caller work; the caller owns transaction recovery. Selector validation errors are never suppressed by `@IgnoreError`.

## Semaphore wait

`z.usp_AcquireSemaphore` validates `@SemaphoreName`, `@TotalCount > 0`, `@LockOwner` (`Transaction` or `Session`), and `@LockTimeout >= -1`. Waits are bounded by `@LockTimeout` (`-1` waits indefinitely; `0` does not wait). Session context keys are derived from `SHA2_256` of `db_id()`, owner, and semaphore name.

## Generated SQL

Schema copy preserves identity seed/increment when requested and selects table/index/default categories independently. It does not clone foreign keys, CHECK constraints, triggers, permissions or extended properties. `@ShowPlan = 1` returns ordered scripts without generated-SQL execution; `@PrintCode = 1` alone prints and executes. With `@CopyTableSchema = 0`, an existing target is required. See [schema-copy behavior and limits](reference/schema-copy.md).

`z.fn_BuildQueryMergeTable` leaves a source-query placeholder (`--<<YourQuery>>`). `z.usp_GetQueryResultToSQL` formats temporal values with style 120 (sub-second fractional precision is truncated). Validate generated output against representative data.

## Removal

`z.usp_RemoveSchemaZ` drops `z` plan guides, schema objects (including bound Service Broker services before queues), user-defined types, XML schema collections, shared AsyncChannel Broker contracts/message types, generic partition schemes/functions, itself, and schema `z`. External objects outside schema `z` (such as SQL Agent jobs in `msdb` or cross-schema references) are not automatically removed and can block dropping referenced objects or schema `z`.
