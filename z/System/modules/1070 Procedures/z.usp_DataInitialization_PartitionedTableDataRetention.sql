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
