# Partition boundaries reference

[Object index](readme.md)

## z.fn_BuildQueryCreatePartitionForDateRange

[Source](../../modules/1020%20Functions/z.fn_BuildQueryCreatePartitionForDateRange.sql)

```sql
create or alter function z.fn_BuildQueryCreatePartitionForDateRange
(
	@ObjectName nvarchar(300) = null,
	@PartitionFunctionName nvarchar(128) = null,
	@PartitionRangeType varchar(30) = 'Monthly', -- 'Minute','Hourly', 'Daily', 'Weekly', 'Monthly', 'Yearly'
	@PartitionRangeTypeInterval int = 1,
	@DateFrom datetime = null,
	@DateTo datetime = null,
	@NumberOfPartitions int = 3,  -- can be positive or negative. When positive, partitions will be added in the future. When negative, partitions will be added backward.
	@FileGroup nvarchar(128) = null
)
returns @ret table(Ordinal int identity(1,1), SQL nvarchar(max), Date datetime)
```

## z.usp_CreatePartitionForDateRange

[Source](../../modules/1070%20Procedures/z.usp_CreatePartitionForDateRange.sql)

```sql
create or alter procedure z.usp_CreatePartitionForDateRange
(
	@ObjectName nvarchar(300) = null,
	@PartitionFunctionName nvarchar(128) = null,
	@PartitionRangeType varchar(30) = 'Monthly', -- 'Minute','Hourly', 'Daily', 'Weekly', 'Monthly', 'Yearly'
	@PartitionRangeTypeInterval int = 1,
	@DateFrom datetime = null,
	@DateTo datetime = null,
	@NumberOfPartitions int = 3,  -- can be positive or negative. When positive, partitions will be added in the future. When negative, partitions will be added backward.
	@FileGroup nvarchar(128) = null,
	@ShowPlan bit = 0
)
```

## Parameters and returned plan

Use ObjectName or PartitionFunctionName to identify the existing function. Supported key types are date, datetime, datetime2, smalldatetime or bigint System IDs. Date keys require Daily or coarser periods. Default period Monthly, interval 1, DateFrom current UTC time when null, DateTo computed from count when null, count 3, storage default filegroup when null/Default/[Default]. Negative count requests backward boundaries.

Both rounded endpoints are included. The TVF returns Ordinal identity, SQL and Date. Procedure ShowPlan returns Ordinal, Date and SQL in Ordinal order; the default ShowPlan = 0 preserves execution behavior. Each missing boundary emits next-used statements for all schemes, a split and next-used statements again. Validation failures become executable throw text in a row. Selecting output does not throw those generated errors.

## Execution and limits

With ShowPlan = 1, the procedure only reads metadata and returns the builder SQL. It does not execute generated errors, next-used statements or splits, start a transaction or acquire the maintenance application lock. Preview supports INSERT EXEC capture and caller transactions; it preserves implicit_transactions and xact_abort settings. Runtime planning errors return an error SQL row with Ordinal 0 and Date NULL. A NULL ShowPlan parameter is rejected.

With ShowPlan = 0, the procedure resolves the function, acquires the same per-function session application lock as automatic maintenance, generates SQL under that lock and executes it by Ordinal in its own transaction. Caller transactions and implicit_transactions on are rejected without rolling back caller work. Metadata/function/scheme DDL permissions are required.

Weekly is supported and starts Monday independently of DATEFIRST; intervals must be positive. Invalid interval/type inputs produce executable error rows rather than throwing during function selection. Keep date/count products within SQL Server arithmetic and key-type limits.

Candidates are converted to the partition key type before comparing with existing boundaries. Existing boundaries are omitted during generation and rechecked immediately before SPLIT. Maintenance procedures share a lock; manual DDL still needs coordination. This standalone interface can split populated data and incur data movement. Use automatic maintenance for populated-tail switch-aside recovery without historical backfill.
