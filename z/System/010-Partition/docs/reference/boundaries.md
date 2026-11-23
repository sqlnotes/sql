# Partition boundaries reference

[Object index](readme.md)

Add missing boundaries to an existing date-based partition function. Use the function to generate a plan, or the procedure to preview or execute it. These helpers leave existing boundaries in place and do not expire data.

## z.fn_BuildQueryCreatePartitionForDateRange

[Source](../../modules/1020%20Functions/z.fn_BuildQueryCreatePartitionForDateRange.sql)

Returns the SQL needed for the requested date range without executing it. Supply either a table using the function or the partition-function name directly.

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

Executes the boundary plan, or returns it for review with `@ShowPlan = 1`. Execution affects every partition scheme using the selected function.

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

Use `@ObjectName` or `@PartitionFunctionName` to identify the existing function. Supported keys are date, datetime, datetime2, smalldatetime or bigint System IDs. Date keys require Daily or coarser periods.

| Parameter | Meaning |
| --- | --- |
| `@PartitionRangeType`, `@PartitionRangeTypeInterval` | Period and number of periods between boundaries; defaults are Monthly and 1. |
| `@DateFrom`, `@DateTo` | Requested range. An omitted start uses current UTC time; an omitted end is calculated from the count. Both rounded endpoints are included. |
| `@NumberOfPartitions` | Number of interval increments when calculating the end; defaults to 3. A negative value requests boundaries backward in time. |
| `@FileGroup` | Filegroup for new partitions. NULL, Default and [Default] use the database default. |
| `@ShowPlan` | Procedure only: 1 returns the proposed SQL; 0 executes it. |

The function returns `Ordinal`, `SQL` and `Date`; procedure preview returns `Ordinal`, `Date` and `SQL` in execution order. An error can appear as executable error text in a plan row. Reading the plan does not execute that error or any partition changes.

## Execution and limits

With ShowPlan = 1, the procedure only reads metadata and returns the builder SQL. It does not execute generated errors, next-used statements or splits, start a transaction or acquire the maintenance application lock. Preview supports INSERT EXEC capture and caller transactions; it preserves implicit_transactions and xact_abort settings. Runtime planning errors return an error SQL row with Ordinal 0 and Date NULL. A NULL ShowPlan parameter is rejected.

With ShowPlan = 0, the procedure resolves the function, acquires the same per-function session application lock as automatic maintenance, generates SQL under that lock and executes it by Ordinal in its own transaction. Caller transactions and implicit_transactions on are rejected without rolling back caller work. Metadata/function/scheme DDL permissions are required.

Weekly is supported and starts Monday independently of DATEFIRST; intervals must be positive. Invalid interval/type inputs produce executable error rows rather than throwing during function selection. Keep date/count products within SQL Server arithmetic and key-type limits.

Candidates are converted to the partition key type before comparing with existing boundaries. Existing boundaries are omitted during generation and rechecked immediately before SPLIT. Maintenance procedures share a lock; manual DDL still needs coordination. This standalone interface can split populated data and incur data movement. Use automatic maintenance for populated-tail switch-aside recovery without historical backfill.
