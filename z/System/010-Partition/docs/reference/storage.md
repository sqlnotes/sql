# Storage and retention policy

[Object index](readme.md)

The shared partition functions define how date-based data is divided. `z.PartitionedTableDataRetention` supplies the policy that decides how far ahead to prepare partitions and when old data expires. A policy belongs to a function, so it can affect several tables together.

## PF_SchemaZPartitionGeneric and PS_SchemaZPartitionGeneric

[Source](../../../baseline/2010%20Partitions/SchemaZPartitionGeneric.sql).

Use `PF_SchemaZPartitionGeneric` and `PS_SchemaZPartitionGeneric` for datetime-encoded bigint System IDs. Use `PF_SchemaZPartitionGenericDateTime` and `PS_SchemaZPartitionGenericDateTime` for datetime keys. Both begin without boundaries and use the default filegroup. The bigint function uses `range left`; the datetime function uses `range right`.

These objects belong to the System baseline. Deployment creates missing definitions when that baseline is eligible (System at 0.0.0 or its first version, 0.0.1), but does not repair an existing mismatched definition. Initialization adds missing policies for both pairs and preserves custom settings.

## z.PartitionedTableDataRetention

[Source](../../baseline/2020%20Tables/z.PartitionedTableDataRetention.sql). Primary key is PartitionFunctionName; there is no catalog foreign key or positive-value check. Policy access uses normal table permissions.

| Column | Type, nullability and default | Meaning |
| --- | --- | --- |
| PartitionFunctionName | nvarchar(128), not null, no default | Database partition function to maintain |
| PartitionRangeType | varchar(20), not null, Monthly | Minute, Hourly, Daily, Weekly, Monthly, Yearly enforced by check; Weekly starts Monday UTC |
| PartitionRangeTypeInterval | int, not null, 1 | Number of periods per boundary; use positive values |
| ForwardedPartitionCount | int, not null, 3 | Number of future boundaries; zero adds none |
| NextPartitionFileGroup | nvarchar(128), not null, no default | Writable row filegroup for future splits; Default resolves database default. The first LEFT recovery split preserves each scheme's original tail filegroup; subsequent splits use this setting |
| PartitionsToKeep | int, not null, 12 | Nonnegative cutoff distance in period increments; -1 disables expiration |
| ArchivedSwappedPartitions | bit, nullable, 1 | 1 keeps switched tables; 0 drops them; NULL is rejected by maintenance |

System [initializer](../../../890-SystemBeforePost/1010%20Procedures/z.usp_DataInitialization_PartitionedTableDataRetention.sql) inserts missing generic bigint and datetime rows with monthly/1, forward 3, Default, keep 6, archive 0. Deployment root post repeats this initialization without updating existing policies. These shipped values differ from table defaults.

Retention horizon is based on period starts and boundary selection, not row timestamps independently. Shared function, range direction and index topology affect the actual plan.
