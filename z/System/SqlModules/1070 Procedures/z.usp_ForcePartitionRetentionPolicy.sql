create or alter procedure z.usp_ForcePartitionRetentionPolicy
as
begin
	set nocount on
	declare @SQL nvarchar(max), @Today datetime = getutcdate()
	begin try
	begin tran
	declare c cursor local static for
		select f.SQL
		from z.PartitionedTableDataRetention p
			cross apply z.fn_BuildQueryForcePartitionRetentionPolicy(p.PartitionFunctionName, p.PartitionRangeType, p.PartitionRangeTypeInterval, p.ForwardedPartitionCount, p.NextPartitionFileGroup, p.PartitionsToKeep, p.ArchivedSwappedPartitions, @Today) f
		order by p.PartitionFunctionName ,f.Ordinal
	open c
	fetch next from c into @SQL
	while @@fetch_status = 0
	begin
		exec(@SQL)
		fetch next from c into @SQL
	end
	commit
	end try
	begin catch
		if @@trancount > 0
			rollback;
		throw
	end catch
end
