# Partition object reference

[Guide](../readme.md)

| Object | Reference |
| --- | --- |
| PF_SchemaZPartitionGeneric, PS_SchemaZPartitionGeneric, PF_SchemaZPartitionGenericDateTime, PS_SchemaZPartitionGenericDateTime | [Storage and policy](storage.md) |
| z.PartitionedTableDataRetention | [Storage and policy](storage.md) |
| z.fn_BuildQueryCreatePartitionForDateRange | [Boundary creation](boundaries.md) |
| z.usp_CreatePartitionForDateRange | [Boundary creation](boundaries.md) |
| z.fn_BuildQueryForcePartitionRetentionPolicy | [Retention](retention.md) |
| z.usp_ForcePartitionRetentionPolicy | [Retention](retention.md) |

The retention function's source filename omits Partition (`z.fn_BuildQueryForceRetentionPolicy.sql`); the callable SQL name includes it as shown above.

## Permissions and transactions

Builders return SQL and require catalog visibility; they do not execute generated statements. Grant function access appropriate to a TVF and visibility of the source/storage objects. Execution needs partition-function/scheme DDL permissions, source/target table permissions and schema-copy permissions.

With `@ShowPlan = 0`, both procedures reject caller transactions and implicit_transactions on, and acquire a per-function session application lock. With `@ShowPlan = 1`, both allow caller transaction modes and acquire no maintenance application lock. Automatic maintenance uses one transaction per recovery or expired boundary; independent functions continue after a failure. Preview executes no generated SQL. Manual DDL can still invalidate a plan. Review all generated statements before applying maintenance to a shared function.

## Generated objects

Retention targets are same-schema tables named `<SourceTable>_Partition_YYYYMMDD`, adding `_HHMM` for Minute/Hourly. Names are based on decoded boundary time. Any existing target causes an error, even if empty. Targets are kept only with archive enabled; otherwise switched rows are removed by dropping them. System's copy helper creates table/index/default definitions, with its documented omissions.
