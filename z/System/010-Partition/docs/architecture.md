# Partition architecture

[Guide](readme.md) · [Reference](reference/readme.md)

## Objects and dependencies

`PF_SchemaZPartitionGeneric` is a database-level bigint function, `range left`, initially no boundaries. `PS_SchemaZPartitionGeneric` places all partitions on `[Default]`. System owns these shared storage definitions and the datetime equivalents PF_SchemaZPartitionGenericDateTime and PS_SchemaZPartitionGenericDateTime. Guards preserve existing objects without checking their shape.

`z.PartitionedTableDataRetention` stores one policy per function. Shared System helpers calculate periods, encode/decode identifier boundaries, expose partition/index metadata and copy table schemas. Monitoring and Trace depend on the generic scheme; System post writes the shipped policy after all children.

## Generation

The boundary builder resolves a function directly or from heap/clustered table storage, rounds dates to period starts, emits scheme `next used` and function `split range` statements for missing boundaries. Bigint boundaries use System's time encoding.

The retention builder adds future boundaries and selects clustered-index partitions with decoded boundaries at or before the cutoff. It creates same-schema `<Source>_Partition_yyyyMMddHHmm` targets, switches the preceding partition, optionally drops archives and emits merges.

The builder selects `IndexID = 1`; heaps are excluded. It does not comprehensively validate alignment, foreign keys or range direction. Review generated SQL against SQL Server switch requirements.

## Execution and concurrency

The boundary procedure executes its plan in one transaction. The retention procedure uses UTC current time and executes all policies in one transaction. Both catch blocks roll back any open transaction and rethrow, including caller work.

DDL takes schema locks and can move data in populated partitions. No feature application lock serializes maintenance. One worker per affected function is advisable; generation and execution can observe different catalog states.
