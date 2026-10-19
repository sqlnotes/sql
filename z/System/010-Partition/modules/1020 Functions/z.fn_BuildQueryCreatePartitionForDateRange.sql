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
as
begin
	declare @PartitonFunctionID int, @SQL nvarchar(max), @PartitionSchemeName nvarchar(128), @DataSpaceID int, 
			@DataType nvarchar(128), @df datetime2, @dt datetime2, @ID sql_variant
	--- Start validation ---
	if @PartitionFunctionName is null
	begin
		select top 1 @DataSpaceID = data_space_id
		from sys.indexes
		where object_id = object_id(@ObjectName)
			and index_id in (0,1)

		select @PartitionFunctionName = pf.name
		from sys.partition_schemes ps
			inner join sys.partition_functions pf on pf.function_id = ps.function_id
		where data_space_id = @DataSpaceID
	end

	select @PartitonFunctionID = function_id, @PartitionFunctionName = name
	from sys.partition_functions
	where name = @PartitionFunctionName
	if @@rowcount = 0
	begin
		insert into @ret(SQL)
			values('throw 50000, N''Could not find partition function.'', 1;')
		return
	end
	select @DataType = case DataType
							when 'datetime2' then DataType + '('+cast(Scale as varchar(20))+')' 
							else DataType
						end
	from (
			select type_name(system_type_id) DataType, scale Scale
			from sys.partition_parameters
			where function_id = @PartitonFunctionID
		) p
	where DataType in ('date', 'datetime', 'datetime2', 'smalldatetime', 'bigint')
	if @@rowcount = 0
	begin
		insert into @ret(SQL)
			values('throw 50000, N''Partition key data type is not supported.'', 1;')
		return
	end
	if @FileGroup is null or @FileGroup = 'Default' or @FileGroup = '[Default]'
	begin
		select @FileGroup = name from sys.data_spaces where is_default = 1 and type_desc = 'ROWS_FILEGROUP'
	end
	if not exists(select * from sys.filegroups where name = @FileGroup and type = 'FG' and is_read_only = 0)
	begin
		insert into @ret(SQL)
			values('throw 50000, N''Could not find database file group.'', 1;')
		return
	end

	if @DateTo is null and @NumberOfPartitions is null
	begin
		insert into @ret(SQL)
			values('throw 50000, N''@DateTo and @NumberOfPartitions cannot be both NULLs.'', 1;')
		return
	end

	if @PartitionRangeType is null or @PartitionRangeType not in ('Minute','Hourly', 'Daily', 'Weekly', 'Monthly', 'Yearly')
	begin
		insert into @ret(SQL)
			values('throw 50000, N''Invalid parameter @PartitionRangeType. Supported values Minute, Hourly, Daily, Weekly, Monthly, Yearly.'', 1;')
		return
	end

	if @DataType = 'date' and @PartitionRangeType in ('Minute', 'Hourly')
	begin
		insert into @ret(SQL)
			values('throw 50000, N''Date partition keys require Daily or coarser periods.'', 1;')
		return
	end
	if isnull(@PartitionRangeTypeInterval, 0) <= 0
	begin
		insert into @ret(SQL)
			values('throw 50000, N''Invalid parameter  @PartitionRangeTypeInterval.'', 1;')
		return
	end
	--- End validation ---

	if @DateFrom is null
		select @DateFrom = getutcdate()

	select	@DateFrom = z.fn_GetPeriodStart(@DateFrom, @PartitionRangeType, @PartitionRangeTypeInterval, default),
			@DateTo = z.fn_GetPeriodStart(@DateTo, @PartitionRangeType, @PartitionRangeTypeInterval, default)

	select	@DateTo =	isnull(@DateTo,
								case @PartitionRangeType
									when 'Minute' then dateadd(minute, @NumberOfPartitions * @PartitionRangeTypeInterval, @DateFrom)
									when 'Hourly' then dateadd(hour, @NumberOfPartitions * @PartitionRangeTypeInterval, @DateFrom)
									when 'Daily' then dateadd(day, @NumberOfPartitions * @PartitionRangeTypeInterval, @DateFrom)
									when 'Weekly' then dateadd(week, @NumberOfPartitions * @PartitionRangeTypeInterval, @DateFrom)
									when 'Monthly' then dateadd(month, @NumberOfPartitions * @PartitionRangeTypeInterval, @DateFrom)
									when 'Yearly' then dateadd(year, @NumberOfPartitions * @PartitionRangeTypeInterval, @DateFrom)
								end
							)
	
	select	@df = iif(@DateFrom <= @DateTo, @DateFrom, @DateTo),
			@dt = iif(@DateFrom <= @DateTo, @DateTo, @DateFrom)

	declare c cursor static local for
		select name
		from sys.partition_schemes 
		where function_id = @PartitonFunctionID
		order by name
	open c

	while @df <= @dt
	begin
		select @ID = case @DataType
			when 'bigint' then convert(sql_variant, z.fn_GenerateZSequenceID(@df, 0))
			when 'date' then convert(sql_variant, convert(date, @df))
			when 'datetime' then convert(sql_variant, convert(datetime, @df))
			when 'smalldatetime' then convert(sql_variant, convert(smalldatetime, @df))
			else convert(sql_variant, @df) end
		if not exists(
						select * 
						from sys.partition_range_values
						where function_id = @PartitonFunctionID
							and value = @ID
					)
		begin
			fetch first from c into @PartitionSchemeName
			while @@fetch_status = 0
			begin
				select @SQL = 'alter partition scheme '  + quotename(@PartitionSchemeName)+ ' next used ' + quotename(@FileGroup) + ';'
				insert into @ret(SQL, Date)
					values(@SQL, @df)
				fetch next from c into @PartitionSchemeName
			end

			select @SQL = 'declare @ID ' + @DataType + ' = '
						+	case @DataType
								when 'bigint' then cast(@ID as nvarchar(100)) + ';/*'+convert(nvarchar(100), cast(@df as date), 121)+'*/'
								else 'convert(' + @DataType + ', convert(datetime2(7),' + quotename(convert(nvarchar(100), cast(@ID as datetime2), 126), '''') + ', 126))'
							end
						+ ';if not exists(select * from sys.partition_range_values r inner join sys.partition_functions f on f.function_id = r.function_id where f.name = N' + quotename(@PartitionFunctionName, '''') + ' and r.value = @ID) alter partition function ' + quotename(@PartitionFunctionName) + '() split range (@ID);'
			insert into @ret(SQL, Date)
					values(@SQL, @df)
			fetch first from c into @PartitionSchemeName
			while @@fetch_status = 0
			begin
				select @SQL = 'alter partition scheme '  + quotename(@PartitionSchemeName)+ ' next used ' + quotename(@FileGroup) + ';'
				insert into @ret(SQL, Date)
					values(@SQL, @df)
				fetch next from c into @PartitionSchemeName
			end
		end
		
		select	@df =	case @PartitionRangeType
							when 'Minute' then dateadd(minute, @PartitionRangeTypeInterval, @df)
							when 'Hourly' then dateadd(hour, @PartitionRangeTypeInterval, @df)
							when 'Daily' then dateadd(day, @PartitionRangeTypeInterval, @df)
							when 'Weekly' then dateadd(week, @PartitionRangeTypeInterval, @df)
							when 'Monthly' then dateadd(month, @PartitionRangeTypeInterval, @df)
							when 'Yearly' then dateadd(year, @PartitionRangeTypeInterval, @df)
						end
	end
	close c
	deallocate c
	return
end
go