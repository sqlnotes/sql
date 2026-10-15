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
as
begin
	set nocount on;
	if @ShowPlan is null
	begin
		set xact_abort off;
		raiserror('ShowPlan must be specified.', 16, 1);
		return;
	end
	if @ShowPlan = 1
	begin
		declare @PreviewImplicit bit = iif((@@options & 2) = 2, 1, 0),
				@PreviewXactAbort bit = iif((@@options & 16384) = 16384, 1, 0), @PreviewError nvarchar(2048);
		set implicit_transactions off;
		set xact_abort off;
		begin try
			select Ordinal, Date, SQL
			from z.fn_BuildQueryCreatePartitionForDateRange(@ObjectName, @PartitionFunctionName, @PartitionRangeType,
				@PartitionRangeTypeInterval, @DateFrom, @DateTo, @NumberOfPartitions, @FileGroup)
			order by Ordinal;
		end try
		begin catch
			select @PreviewError = error_message();
			select 0 Ordinal, convert(datetime, null) Date,
				convert(nvarchar(max), N'throw 50001, N''' + replace(@PreviewError, N'''', N'''''') + N''', 1;') SQL;
		end catch
		-- Restore after SELECT so preview cannot start a new implicit transaction.
		if @PreviewImplicit = 1 set implicit_transactions on;
		if @PreviewXactAbort = 1 set xact_abort on;
		return;
	end
	if @@trancount > 0 or (@@options & 2) = 2
	begin
		set xact_abort off;
		raiserror('Partition maintenance requires no caller transaction and implicit_transactions off.', 16, 1);
		return;
	end
	set xact_abort on;
	declare @SQL nvarchar(max), @FunctionName sysname, @Resource nvarchar(255), @LockResult int, @LockHeld bit = 0;
	select @FunctionName = f.name
	from sys.partition_functions f
	where f.name = @PartitionFunctionName;
	if @PartitionFunctionName is null
		select @FunctionName = f.name
		from sys.indexes i
			inner join sys.partition_schemes s on s.data_space_id = i.data_space_id
			inner join sys.partition_functions f on f.function_id = s.function_id
		where i.object_id = object_id(@ObjectName) and i.index_id in (0, 1);
	if @FunctionName is null throw 50000, 'Could not find partition function.', 1;
	select @Resource = N'SchemaZ.Partition:' + @FunctionName;
	begin try
		exec @LockResult = sys.sp_getapplock @Resource = @Resource, @LockMode = 'Exclusive', @LockOwner = 'Session', @LockTimeout = 0;
		if @LockResult < 0 throw 50000, 'Another session is managing this partition function.', 1;
		select @LockHeld = 1;
		declare c cursor local static for
			select SQL
			from z.fn_BuildQueryCreatePartitionForDateRange(null, @FunctionName, @PartitionRangeType, @PartitionRangeTypeInterval, @DateFrom, @DateTo, @NumberOfPartitions, @FileGroup)
			order by Ordinal;
		open c;
		begin tran;
		fetch next from c into @SQL;
		while @@fetch_status = 0
		begin
			exec sys.sp_executesql @SQL;
			fetch next from c into @SQL;
		end
		close c;
		deallocate c;
		commit;
		exec sys.sp_releaseapplock @Resource = @Resource, @LockOwner = 'Session';
	end try
	begin catch
		if @@trancount > 0 rollback;
		if @LockHeld = 1 exec sys.sp_releaseapplock @Resource = @Resource, @LockOwner = 'Session';
		throw;
	end catch
end
