# Partition object reference

[Guide](../readme.md)

| Object | Reference |
| --- | --- |
| PF_SchemaZPartitionGeneric, PS_SchemaZPartitionGeneric | [Storage and policy](storage.md) |
| z.PartitionedTableDataRetention | [Storage and policy](storage.md) |
| z.fn_BuildQueryCreatePartitionForDateRange | [Boundary creation](boundaries.md) |
| z.usp_CreatePartitionForDateRange | [Boundary creation](boundaries.md) |
| z.fn_BuildQueryForcePartitionRetentionPolicy | [Retention](retention.md) |
| z.usp_ForcePartitionRetentionPolicy | [Retention](retention.md) |

The retention function's source filename omits Partition (`z.fn_BuildQueryForceRetentionPolicy.sql`); the callable SQL name includes it as shown above.

## Permissions and transactions

Builders return SQL and require catalog visibility; they do not execute generated statements. Grant function access appropriate to a TVF and visibility of the source/storage objects. Execution needs partition-function/scheme DDL permissions, source/target table permissions and schema-copy permissions.

Both execution procedures start transactions and roll back any open transaction on error; a caller transaction can be rolled back. They do not acquire a feature semaphore. Concurrent changes can invalidate a plan. Review all generated statements before applying maintenance to a shared function.

## Generated objects

Retention targets are same-schema tables named `<SourceTable>_Partition_yyyyMMddHHmm`. Names are based on decoded boundary time. Existing empty targets are dropped; nonempty targets raise an error. Targets are kept only with archive enabled; otherwise switched rows are removed by dropping them. System's copy helper creates table/index/default definitions, with its documented omissions.
