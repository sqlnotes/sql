# Partition retention reference

[Object index](readme.md)

## z.fn_BuildQueryForcePartitionRetentionPolicy

[Source](../../modules/1030%20Functions/z.fn_BuildQueryForceRetentionPolicy.sql)

```sql
create or alter function z.fn_BuildQueryForcePartitionRetentionPolicy
(
    @PartitionFunctionName nvarchar(128),
    @PartitionRangeType varchar(20),
    @PartitionRangeTypeInterval int,
    @ForwardedPartitionCount int,
    @NextPartitionFileGroup nvarchar(128),
    @PartitionsToKeep int,
    @ArchivedSwappedPartitions bit,
	@Today datetime = null
)
returns @ret table(Ordinal int identity(1,1), Name varchar(300), SQL nvarchar(max))
```

## z.usp_ForcePartitionRetentionPolicy

[Source](../../modules/1070%20Procedures/z.usp_ForcePartitionRetentionPolicy.sql)

```sql
create or alter procedure z.usp_ForcePartitionRetentionPolicy
```

## Inputs and returned plan

The TVF takes all policy columns plus optional Today (null uses local getdate()). It returns Ordinal identity, Name varchar(300), SQL nvarchar(max). PartitionsToKeep is normalized to absolute value (null becomes 0). Cutoff is current period start minus the retained-period count; it selects decoded boundaries <= cutoff.

The first plan rows create future partitions, followed by per-table switch/archive/merge blocks. ArchivedSwappedPartitions=1 keeps targets; otherwise generated SQL drops them. Targets follow the same-schema Source_Partition_yyyyMMddHHmm pattern. An existing empty target is dropped/recreated; nonempty target raises an error.

## Execution and limits

The no-parameter procedure applies every row in z.PartitionedTableDataRetention, captures getutcdate() once and supplies it as Today, sorts function name/Ordinal, then executes in one transaction. No explicit result set/output parameter. Catch rolls back any open transaction and rethrows. It needs source metadata, table/schema DDL, partition DDL and schema-copy permissions.

Dependencies: z.fn_GetPeriodStart, z.fn_BuildQueryCreatePartitionForDateRange, z.v_PartitionedIndexes and generated z.usp_CopyTableSchema calls. The source filename differs from the function definition name.

Weekly cutoff is missing. Heap and clustered partitions (IndexID 0/1) are selected. The builder switches the partition preceding each selected boundary row (`PartitionNumber - 1`), passing that exact number to schema copy so each target index inherits the switched partition's filegroup and compression. It does not validate range direction; source features and engine restrictions can still prevent switching.

Partitions are emitted in descending ordinal order so merging a higher boundary does not renumber partitions still awaiting switch-out. Within a boundary group, rn=1 is chosen by descending quoted SourceObject and receives the merge; emission sorts the same quoted SourceObject ascending, placing the merge after the group's switches. Review all sharing tables. No feature lock protects plan generation/execution.
