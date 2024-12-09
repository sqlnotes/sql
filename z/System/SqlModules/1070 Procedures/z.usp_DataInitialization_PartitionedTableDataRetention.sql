create or alter procedure z.usp_DataInitialization_PartitionedTableDataRetention
as
begin
	set nocount on
	-- Initialize [z].[PartitionedTableDataRetention]
	-- exec z.usp_DataInitializationHelper @FullObjectName = '[z].[PartitionedTableDataRetention]' , @ForceIdentityColumnInsert = 1, @ForceMatchedDataUpdate = 1, @PrimaryKeys = null, @ExcludedColumns = null
	;with s as 
	(
		select cast([PartitionFunctionName] as nvarchar(128)) as [PartitionFunctionName],cast([PartitionRangeType] as varchar(20)) as [PartitionRangeType],cast([PartitionRangeTypeInterval] as int) as [PartitionRangeTypeInterval],cast([ForwardedPartitionCount] as int) as [ForwardedPartitionCount],cast([NextPartitionFileGroup] as nvarchar(128)) as [NextPartitionFileGroup],cast([PartitionsToKeep] as int) as [PartitionsToKeep],cast([ArchivedSwappedPartitions] as bit) as [ArchivedSwappedPartitions]
		from (
				values(N'PF_zPartitionGeneric',N'Monthly',1,3,N'Default',6,0)
			) v([PartitionFunctionName],[PartitionRangeType],[PartitionRangeTypeInterval],[ForwardedPartitionCount],[NextPartitionFileGroup],[PartitionsToKeep],[ArchivedSwappedPartitions])
	)
	merge [z].[PartitionedTableDataRetention] t
	using s on s.[PartitionFunctionName]= t.[PartitionFunctionName]
	when not matched then
		insert ([PartitionFunctionName],[PartitionRangeType],[PartitionRangeTypeInterval],[ForwardedPartitionCount],[NextPartitionFileGroup],[PartitionsToKeep],[ArchivedSwappedPartitions])
		values(s.[PartitionFunctionName],s.[PartitionRangeType],s.[PartitionRangeTypeInterval],s.[ForwardedPartitionCount],s.[NextPartitionFileGroup],s.[PartitionsToKeep],s.[ArchivedSwappedPartitions])
	when matched and (s.[PartitionRangeType] is null and t.[PartitionRangeType] is not null or s.[PartitionRangeType] is not null and t.[PartitionRangeType] is null or s.[PartitionRangeType] <> t.[PartitionRangeType] or s.[PartitionRangeTypeInterval] is null and t.[PartitionRangeTypeInterval] is not null or s.[PartitionRangeTypeInterval] is not null and t.[PartitionRangeTypeInterval] is null or s.[PartitionRangeTypeInterval] <> t.[PartitionRangeTypeInterval] or s.[ForwardedPartitionCount] is null and t.[ForwardedPartitionCount] is not null or s.[ForwardedPartitionCount] is not null and t.[ForwardedPartitionCount] is null or s.[ForwardedPartitionCount] <> t.[ForwardedPartitionCount] or s.[NextPartitionFileGroup] is null and t.[NextPartitionFileGroup] is not null or s.[NextPartitionFileGroup] is not null and t.[NextPartitionFileGroup] is null or s.[NextPartitionFileGroup] <> t.[NextPartitionFileGroup] or s.[PartitionsToKeep] is null and t.[PartitionsToKeep] is not null or s.[PartitionsToKeep] is not null and t.[PartitionsToKeep] is null or s.[PartitionsToKeep] <> t.[PartitionsToKeep] or s.[ArchivedSwappedPartitions] is null and t.[ArchivedSwappedPartitions] is not null or s.[ArchivedSwappedPartitions] is not null and t.[ArchivedSwappedPartitions] is null or s.[ArchivedSwappedPartitions] <> t.[ArchivedSwappedPartitions]) then 
	update set  t.[PartitionRangeType]= s.[PartitionRangeType], t.[PartitionRangeTypeInterval]= s.[PartitionRangeTypeInterval], t.[ForwardedPartitionCount]= s.[ForwardedPartitionCount], t.[NextPartitionFileGroup]= s.[NextPartitionFileGroup], t.[PartitionsToKeep]= s.[PartitionsToKeep], t.[ArchivedSwappedPartitions]= s.[ArchivedSwappedPartitions]
	;
end
