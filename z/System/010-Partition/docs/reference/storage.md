# Storage and retention policy

[Object index](readme.md)

## PF_SchemaZPartitionGeneric and PS_SchemaZPartitionGeneric

[Source](../../baseline/2010%20Partitions/SchemaZPartitionGeneric.sql). Database-level `bigint`, `range left` function, initially no boundaries; scheme `all to ([Default])`. Existence guards do not reconcile a preexisting mismatched definition. Boundary maintenance uses System ID time encoding.

## z.PartitionedTableDataRetention

[Source](../../baseline/2020%20Tables/z.PartitionedTableDataRetention.sql). Primary key is PartitionFunctionName; there is no catalog foreign key or positive-value check. Policy access uses normal table permissions.

| Column | Type, nullability and default | Meaning |
| --- | --- | --- |
| PartitionFunctionName | nvarchar(128), not null, no default | Database partition function to maintain |
| PartitionRangeType | varchar(20), not null, Monthly | Minute, Hourly, Daily, Weekly, Monthly, Yearly enforced by check; Weekly implementation incomplete |
| PartitionRangeTypeInterval | int, not null, 1 | Number of periods per boundary; use positive values |
| ForwardedPartitionCount | int, not null, 3 | Forward period increments; endpoints are inclusive |
| NextPartitionFileGroup | nvarchar(128), not null, no default | Existing filegroup for future splits; Default resolves database default |
| PartitionsToKeep | int, not null, 12 | Cutoff distance in period increments; builder normalizes absolute/null count |
| ArchivedSwappedPartitions | bit, nullable, 1 | 1 keeps switched tables; other values take generated drop branch |

System [initializer](../../../modules/1070%20Procedures/z.usp_DataInitialization_PartitionedTableDataRetention.sql) overrides the generic row to monthly/1, forward 3, Default, keep 6, archive 0. Deployment root post repeats this initialization. These shipped values differ from table defaults.

Retention horizon is based on period starts and boundary selection, not row timestamps independently. Shared function, range direction and index topology affect the actual plan.
