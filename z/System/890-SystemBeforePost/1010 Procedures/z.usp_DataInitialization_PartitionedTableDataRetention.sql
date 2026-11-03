/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/890-SystemBeforePost/1010%20Procedures/z.usp_DataInitialization_PartitionedTableDataRetention.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/docs/reference/procedures.md#zusp_datainitialization_partitionedtabledataretention

Inserts missing monthly retention policies for the shared bigint and datetime partition
functions without overwriting existing policies.
*/
create or alter procedure z.usp_DataInitialization_PartitionedTableDataRetention
as
begin
	set nocount, xact_abort on;
	;with s as
	(
		select v.PartitionFunctionName, 'Monthly' PartitionRangeType, 1 PartitionRangeTypeInterval,
			3 ForwardedPartitionCount, N'Default' NextPartitionFileGroup, 6 PartitionsToKeep, cast(0 as bit) ArchivedSwappedPartitions
		from (values(N'PF_SchemaZPartitionGeneric'), (N'PF_SchemaZPartitionGenericDateTime')) v(PartitionFunctionName)
		where exists(select * from sys.partition_functions f where f.name = v.PartitionFunctionName)
	)
	merge z.PartitionedTableDataRetention as t using s on s.PartitionFunctionName = t.PartitionFunctionName
	when not matched then
		insert (PartitionFunctionName, PartitionRangeType, PartitionRangeTypeInterval, ForwardedPartitionCount, NextPartitionFileGroup, PartitionsToKeep, ArchivedSwappedPartitions)
		values(s.PartitionFunctionName, s.PartitionRangeType, s.PartitionRangeTypeInterval, s.ForwardedPartitionCount, s.NextPartitionFileGroup, s.PartitionsToKeep, s.ArchivedSwappedPartitions);
end
