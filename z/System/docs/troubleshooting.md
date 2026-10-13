# System troubleshooting

[Guide](readme.md) · [Source-linked object reference](reference/readme.md)

## Compatibility

`z.v_Indexes` references `sys.indexes.optimize_for_sequential_key` and schema-copy emits that option. The minimum supported version is SQL Server 2019 (15.x), which supports these paths. Microsoft lists this column as available from SQL Server 2019 in its [sys.indexes reference](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-indexes-transact-sql?view=sql-server-ver17).

## Environment detection

`z.fn_IsAzureDatabase` returns 0 in both branches. `z.fn_IsHostedDatabase` therefore recognizes only the current Amazon RDS heuristic. Do not use either as an authoritative feature check.

## Naming errors

`z.usp_ForceNamingConvention` prints the error for `@IgnoreError = 1`, then throws unconditionally. Completed renames may persist; its catch can roll back a caller transaction.

## Semaphore wait

No overall timeout exists. Nonpositive capacity creates endless retries. The resource becomes a session-context key prefixed with `Semaphore-`, subject to SQL Server key length. Use short names and positive, consistent capacities.

## Generated SQL

Schema copy preserves identity seed/increment when requested and selects table/index/default categories independently. It does not clone foreign keys, CHECK constraints, triggers, permissions or extended properties. `@ShowPlan = 1` returns ordered scripts without generated-SQL execution; `@PrintCode = 1` alone prints and executes. With `@CopyTableSchema = 0`, an existing target is required. See [schema-copy behavior and limits](reference/schema-copy.md).

`z.fn_BuildQueryMergeTable` leaves a source-query placeholder. Identity omission can produce empty list entries; legacy text/image comparisons emit invalid `t.cast(...)`. `z.usp_GetQueryResultToSQL` uses temporal style 120 (fractional precision can be lost) and uses byte length for its `nchar` type branch. Validate output against representative data.

## Removal

`z.usp_RemoveSchemaZ` catches and prints drop failures then retries a selected object; a persistent dependency can cause a nonprogressing loop. It is destructive and does not guarantee complete SQL Agent/Broker cleanup. It is not a deployment rollback mechanism.
