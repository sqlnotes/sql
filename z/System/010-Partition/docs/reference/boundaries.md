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
	@FileGroup nvarchar(128) = null
)
```

## Parameters and returned plan

Use ObjectName or PartitionFunctionName to identify the existing function. Supported key types are date-like types or bigint System IDs. Default period Monthly, interval 1, DateFrom current local time when null, DateTo computed from count when null, count 3, storage default filegroup when null/Default/[Default]. Negative count requests backward boundaries.

Both rounded endpoints are included. The TVF returns Ordinal identity, SQL and Date. Each missing boundary emits next-used statements for all schemes, a split and next-used statements again. Validation failures become executable raiserror text in a row. Selecting output does not throw those generated errors.

## Execution and limits

The procedure runs SQL by Ordinal in a transaction; catch rolls back any open transaction and rethrows. No explicit result set or output parameter is declared. Appropriate function/scheme DDL and source metadata permission are needed.

Weekly is accepted but missing from computed end-date and iteration cases. The interval validation guard never rejects zero/null; zero can divide by zero, null can yield an empty/incomplete plan and abs(INT_MIN) overflows. Use positive intervals and a tested bounded date span.

Existing boundaries are omitted based on catalog state during generation. Concurrent DDL can make the plan stale. Splitting populated partitions can incur data movement, locks and log use.
