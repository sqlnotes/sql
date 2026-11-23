# System troubleshooting

[Guide](readme.md) · [Source-linked object reference](reference/readme.md)

Use this page when a shared helper fails, waits unexpectedly, or produces a result you did not expect. It links each symptom to the relevant usage or reference details.

## Compatibility

Schema Z requires SQL Server 2019 (15.x) or later. Older versions cannot read some catalog fields used by the index view or execute all schema-copy options. See the [System guide](readme.md#compatibility-and-permissions).

## Environment detection

`z.fn_IsHostedDatabase` combines [Azure engine-edition detection](reference/functions.md#zfn_isazuredatabase) with the Amazon RDS heuristic. A SQL Server VM uses its installed SQL Server edition regardless of cloud provider.

## Naming errors

`z.usp_ForceNamingConvention` requires an explicit schema/table selector. Preview with `@ShowPlan = 1` before applying renames. `@IgnoreError = 0` stops on the first rename failure; `1` prints the error and continues with other candidates. Renaming is non-atomic, so completed changes may persist after a later failure. The procedure does not roll back caller work; the caller owns transaction recovery. Selector validation errors are never suppressed by `@IgnoreError`.

## Semaphore wait

Check that the name is nonempty, capacity is positive, and an active transaction exists for a Transaction-owned permit. A timeout of `0` scans the slots once. The default `-1` waits indefinitely. If error 15665 occurs, check how many distinct semaphore names the connection has used. Explicit release clears the entry for its name, and closing the connection clears its session context. [Semaphore ownership and cleanup](reference/coordination.md#semaphores)

## Generated SQL

Schema copy preserves identity seed/increment when requested and selects table/index/default categories independently. It does not clone foreign keys, CHECK constraints, triggers, permissions or extended properties. `@ShowPlan = 1` returns ordered scripts without generated-SQL execution; `@PrintCode = 1` alone prints and executes. With `@CopyTableSchema = 0`, an existing target is required. See [schema-copy behavior and limits](reference/schema-copy.md).

`z.fn_BuildQueryMergeTable` leaves a source-query placeholder (`--<<YourQuery>>`). `z.usp_GetQueryResultToSQL` formats temporal values with style 120 (sub-second fractional precision is truncated). Validate generated output against representative data.

## Removal

`z.usp_RemoveSchemaZ` drops `z` plan guides, schema objects (including bound Service Broker services before queues), user-defined types, XML schema collections, shared AsyncChannel Broker contracts/message types, generic partition schemes/functions, itself, and schema `z`. External objects outside schema `z` (such as SQL Agent jobs in `msdb` or cross-schema references) are not automatically removed and can block dropping referenced objects or schema `z`.
