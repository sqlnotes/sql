/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/010-Partition/baseline/2020%20Tables/z.PartitionedTableDataRetention.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/010-Partition/docs/reference/storage.md#zpartitionedtabledataretention

Stores partition-boundary creation, retention and archive policies by partition function.
*/
if object_id('z.PartitionedTableDataRetention') is null
begin
	create table z.PartitionedTableDataRetention
	(
		PartitionFunctionName nvarchar(128) not null,
		PartitionRangeType varchar(20) not null constraint DF_z_PartitionedTableDataRetention_PartitionRangeType default('Monthly'),
		PartitionRangeTypeInterval int not null  constraint DF_z_PartitionedTableDataRetention_PartitionRangeTypeInterval default(1),
		ForwardedPartitionCount int not null constraint DF_z_PartitionedTableDataRetention_ForwardedPartitionCount default(3),
		NextPartitionFileGroup nvarchar(128) not null,
		PartitionsToKeep int not null constraint DF_z_PartitionedTableDataRetention_PartitionsToKeep default(12),
		ArchivedSwappedPartitions  bit constraint DF_z_PartitionedTableDataRetention_ArchivedSwappedPartitions default(1),
		constraint PK_z_PartitionedTableDataRetention primary key(PartitionFunctionName),
		constraint [z_PartitionedTableDataRetention:Supported PartitionRangeType are Minute, Hourly, Daily, Weekly, Monthly, Yearly] check(PartitionRangeType in ('Minute','Hourly', 'Daily', 'Weekly', 'Monthly', 'Yearly'))
	)
end