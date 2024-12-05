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
as
begin
	set nocount on
	exec z.usp_RemoveBlocker
	declare @SQL nvarchar(max)
	declare c cursor static local for
		select SQL
		from z.fn_BuildQueryCreatePartitionForDateRange(@ObjectName, @PartitionFunctionName, @PartitionRangeType, @PartitionRangeTypeInterval, @DateFrom, @DateTo, @NumberOfPartitions, @FileGroup)
		order by Ordinal
	open c
	if @@cursor_rows = 0
		return
	begin try
	begin tran
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
		throw;
	end catch	
end