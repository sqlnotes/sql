create or alter function z.fn_BuildQueryForcePartitionRetentionPolicy
(
	@PartitionFunctionName nvarchar(128),
	@PartitionRangeType varchar(20),
	@PartitionRangeTypeInterval int,
	@ForwardedPartitionCount int,
	@NextPartitionFileGroup nvarchar(128),
	@PartitionsToKeep int,
	@ArchivedSwappedPartitions bit,
	@Today datetime = null
)
returns @Ret table(Ordinal int identity(1, 1), Name varchar(300), SQL nvarchar(max), Action varchar(30), TableName nvarchar(517), PartitionNumber int)
as
begin
	declare @FunctionID int, @Fanout int, @Right bit, @DataType nvarchar(128), @BaseType sysname,
			@ThisPeriod datetime, @NextPeriod datetime, @FirstPeriodToKeep datetime, @Error nvarchar(2048),
			@Maximum sql_variant, @MaximumDate datetime2(7), @MaximumID bigint, @LowerLiteral nvarchar(300), @UpperLiteral nvarchar(300),
			@FirstNewDate datetime, @SQL nvarchar(max), @OutSQL nvarchar(max) = N'', @InSQL nvarchar(max) = N'',
			@Source nvarchar(517), @Target nvarchar(517), @Column sysname, @ObjectID int, @Predicate nvarchar(max),
			@BoundaryID int, @Boundary sql_variant, @BoundaryDate datetime2(7), @Suffix nvarchar(30), @Checks nvarchar(max),
			@MergeTarget nvarchar(517), @MergeOutSQL nvarchar(max), @MergeInSQL nvarchar(max), @RestoreSQL nvarchar(max),
			@PreviousBoundary sql_variant, @NextBoundary sql_variant, @CompressionPartition int;
	declare @Tables table(ObjectID int primary key, Source nvarchar(517), SchemaName sysname, TableName sysname, ColumnName sysname);
	declare @Splits table(Ordinal int, SQL nvarchar(max), Date datetime);
	declare @RetainedSuffixes table(Suffix nvarchar(30) primary key);

	select @FunctionID = function_id, @Fanout = fanout, @Right = boundary_value_on_right from sys.partition_functions where name = @PartitionFunctionName;
	select @BaseType = type_name(system_type_id), @DataType = type_name(system_type_id) +
		case when type_name(system_type_id) = 'datetime2' then N'(' + convert(nvarchar(10), scale) + N')' else N'' end
		from sys.partition_parameters where function_id = @FunctionID;
	if @FunctionID is null select @Error = N'Could not find partition function.';
	else if @PartitionRangeType is null or @PartitionRangeType not in ('Minute', 'Hourly', 'Daily', 'Weekly', 'Monthly', 'Yearly') select @Error = N'Unsupported partition period.';
	else if @PartitionRangeTypeInterval is null or @PartitionRangeTypeInterval <= 0 select @Error = N'Partition interval must be positive.';
	else if @ForwardedPartitionCount is null or @ForwardedPartitionCount < 0 select @Error = N'ForwardedPartitionCount must be nonnegative.';
	else if @PartitionsToKeep is null or @PartitionsToKeep < -1 select @Error = N'PartitionsToKeep must be -1 or nonnegative.';
	else if @ArchivedSwappedPartitions is null select @Error = N'ArchivedSwappedPartitions must be specified.';
	else if @BaseType not in ('bigint', 'date', 'datetime', 'datetime2', 'smalldatetime') select @Error = N'Unsupported partition key data type.';
	else if @BaseType = 'date' and @PartitionRangeType in ('Minute', 'Hourly') select @Error = N'Date partition keys require Daily or coarser periods.';
	select @NextPartitionFileGroup = case when @NextPartitionFileGroup is null or @NextPartitionFileGroup in (N'Default', N'[Default]')
		then (select name from sys.filegroups where is_default = 1 and type = 'FG') else @NextPartitionFileGroup end;
	if @Error is null and not exists(select * from sys.filegroups where name = @NextPartitionFileGroup and type = 'FG' and is_read_only = 0)
		select @Error = N'NextPartitionFileGroup must name a writable row filegroup.';
	-- Index-only consumers on a differently partitioned base cannot be switched safely.
	if @Error is null and exists
	(
		select * from sys.indexes i join sys.partition_schemes s on s.data_space_id = i.data_space_id
		where s.function_id = @FunctionID and not exists
		(select * from sys.indexes b join sys.partition_schemes bs on bs.data_space_id = b.data_space_id
			where b.object_id = i.object_id and b.index_id in (0, 1) and bs.function_id = @FunctionID)
	)
		select @Error = N'Partition function has a consumer whose base table uses a different function.';
	insert into @Tables
		select i.object_id, quotename(object_schema_name(i.object_id)) + N'.' + quotename(object_name(i.object_id)),
			   object_schema_name(i.object_id), object_name(i.object_id), col_name(i.object_id, c.column_id)
		from sys.indexes i join sys.partition_schemes s on s.data_space_id = i.data_space_id
			join sys.index_columns c on c.object_id = i.object_id and c.index_id = i.index_id and c.partition_ordinal = 1
		where s.function_id = @FunctionID and i.index_id in (0, 1);
	if @Error is null and exists
	(
		select * from @Tables t join sys.indexes i on i.object_id = t.ObjectID left join sys.partition_schemes s on s.data_space_id = i.data_space_id
		where i.type in (0, 1, 2, 5, 6) and (s.function_id is null or s.function_id <> @FunctionID or not exists
			(select * from sys.index_columns c where c.object_id = i.object_id and c.index_id = i.index_id and c.partition_ordinal = 1 and col_name(c.object_id, c.column_id) = t.ColumnName))
	)
		select @Error = N'All table indexes must align on the managed partition function and column.';
	if @Error is not null
	begin
		insert into @Ret(Name, SQL, Action) values('Error', N'throw 50001, ' + quotename(@Error, '''') + N', 1;', 'Error');
		return;
	end
	select @Today = isnull(@Today, getutcdate()), @ThisPeriod = z.fn_GetPeriodStart(isnull(@Today, getutcdate()), @PartitionRangeType, @PartitionRangeTypeInterval, default);
	select @NextPeriod = case @PartitionRangeType
		when 'Minute' then dateadd(minute, @PartitionRangeTypeInterval, @ThisPeriod)
		when 'Hourly' then dateadd(hour, @PartitionRangeTypeInterval, @ThisPeriod)
		when 'Daily' then dateadd(day, @PartitionRangeTypeInterval, @ThisPeriod)
		when 'Weekly' then dateadd(week, @PartitionRangeTypeInterval, @ThisPeriod)
		when 'Monthly' then dateadd(month, @PartitionRangeTypeInterval, @ThisPeriod)
		when 'Yearly' then dateadd(year, @PartitionRangeTypeInterval, @ThisPeriod) end;
	if @PartitionsToKeep >= 0
		select @FirstPeriodToKeep = case @PartitionRangeType
			when 'Minute' then dateadd(minute, -@PartitionsToKeep * @PartitionRangeTypeInterval, @ThisPeriod)
			when 'Hourly' then dateadd(hour, -@PartitionsToKeep * @PartitionRangeTypeInterval, @ThisPeriod)
			when 'Daily' then dateadd(day, -@PartitionsToKeep * @PartitionRangeTypeInterval, @ThisPeriod)
			when 'Weekly' then dateadd(week, -@PartitionsToKeep * @PartitionRangeTypeInterval, @ThisPeriod)
			when 'Monthly' then dateadd(month, -@PartitionsToKeep * @PartitionRangeTypeInterval, @ThisPeriod)
			when 'Yearly' then dateadd(year, -@PartitionsToKeep * @PartitionRangeTypeInterval, @ThisPeriod) end;
	select @Maximum = value from sys.partition_range_values where function_id = @FunctionID and boundary_id = @Fanout - 1;
	if @BaseType = 'bigint' select @MaximumID = convert(bigint, @Maximum);
	else select @MaximumDate = convert(datetime2(7), @Maximum);
	if @ForwardedPartitionCount > 0
		insert into @Splits
			select f.Ordinal, f.SQL, f.Date
			from z.fn_BuildQueryCreatePartitionForDateRange(null, @PartitionFunctionName, @PartitionRangeType,
				@PartitionRangeTypeInterval, @NextPeriod, null, @ForwardedPartitionCount - 1, @NextPartitionFileGroup) f
			where f.Date is null or @Maximum is null or (@BaseType = 'bigint' and z.fn_GenerateZSequenceID(f.Date, 0) > @MaximumID)
				or (@BaseType <> 'bigint' and convert(datetime2(7), f.Date) > @MaximumDate);
	select @FirstNewDate = min(Date) from @Splits;
	-- LEFT creates the left segment on NEXT USED: retain each scheme's original tail placement.
	if @Right = 0 and @FirstNewDate is not null
		update q set SQL = N'alter partition scheme ' + quotename(s.name) + N' next used ' + quotename(f.name) + N';'
		from @Splits q join sys.partition_schemes s on s.function_id = @FunctionID
			join sys.destination_data_spaces d on d.partition_scheme_id = s.data_space_id and d.destination_id = @Fanout
			join sys.filegroups f on f.data_space_id = d.data_space_id
		where q.Date = @FirstNewDate and q.SQL = N'alter partition scheme ' + quotename(s.name) + N' next used ' + quotename(@NextPartitionFileGroup) + N';';
	if exists(select * from @Splits where Date is null)
	begin
		insert into @Ret(Name, SQL, Action) select 'Error', SQL, 'Error' from @Splits where Date is null order by Ordinal;
		return;
	end
	if @FirstNewDate is not null
	begin
		if exists(select * from @Tables where len(TableName + N'_Partition_SplitHold') > 128 or len(Source) > 256
			or len(quotename(SchemaName) + N'.' + quotename(TableName + N'_Partition_SplitHold')) > 256)
			select @Error = N'Partition holding table name exceeds the supported identifier length.';
		else if exists(select * from @Tables where object_id(quotename(SchemaName) + N'.' + quotename(TableName + N'_Partition_SplitHold')) is not null)
			select @Error = N'Partition holding table already exists. Remove it explicitly before maintenance.';
		if @Error is not null
		begin
			insert into @Ret(Name, SQL, Action) values('Error', N'throw 50001, ' + quotename(@Error, '''') + N', 1;', 'Error');
			return;
		end
		select @UpperLiteral = case when @BaseType = 'bigint' then convert(nvarchar(100), z.fn_GenerateZSequenceID(@FirstNewDate, 0))
			else N'convert(' + @DataType + N',convert(datetime2(7),' + quotename(convert(nvarchar(40), convert(datetime2(7), @FirstNewDate), 126), '''') + N',126))' end,
			   @LowerLiteral = case when @Maximum is null then null when @BaseType = 'bigint' then convert(nvarchar(100), @Maximum)
			else N'convert(' + @DataType + N',convert(datetime2(7),' + quotename(convert(nvarchar(40), convert(datetime2(7), @Maximum), 126), '''') + N',126))' end;
		declare c cursor local static for select ObjectID, Source, quotename(SchemaName) + N'.' + quotename(TableName + N'_Partition_SplitHold'), ColumnName from @Tables order by Source;
		open c;
		fetch next from c into @ObjectID, @Source, @Target, @Column;
		while @@fetch_status = 0
		begin
			select @Predicate = case when @LowerLiteral is not null
				then quotename(@Column) + N' is not null and ' + quotename(@Column) + iif(@Right = 1, N' >= ', N' > ') + @LowerLiteral + N' and '
				when @Fanout > 1 and @Right = 0 then quotename(@Column) + N' is not null and ' else N'' end +
				quotename(@Column) + iif(@Right = 1, N' < ', N' <= ') + @UpperLiteral;
			if @LowerLiteral is null and (@Fanout = 1 or @Right = 1) select @Predicate = N'(' + @Predicate + N') or ' + quotename(@Column) + N' is null';
			select @OutSQL += N'if object_id(' + (N'N''' + replace(@Target, N'''', N'''''') + N'''') + N') is not null throw 50001, N''Partition holding table already exists.'', 1;
exec z.usp_CopyTableSchema @FullSourceTableName = ' + (N'N''' + replace(@Source, N'''', N'''''') + N'''') + N', @FullTargetTableName = ' + (N'N''' + replace(@Target, N'''', N'''''') + N'''') + N', @PartitionNumber = ' + convert(nvarchar(20), @Fanout) + N', @DropTargetTableIfExists = 0, @CopyIdentity = 1;
alter table ' + @Source + N' switch partition ' + convert(nvarchar(20), @Fanout) + N' to ' + @Target + N';
';
			-- Source checks must also be trusted on the holder before switching back.
			select @Checks = string_agg(convert(nvarchar(max), N'alter table ' + @Target + N' with check add constraint ' +
				quotename(N'CK_PartitionHold_' + convert(nvarchar(20), @ObjectID) + N'_' + convert(nvarchar(20), object_id)) + N' check ' + definition collate database_default + N';'), nchar(13) + nchar(10)) within group(order by object_id)
				from sys.check_constraints where parent_object_id = @ObjectID and is_disabled = 0;
			select @InSQL += isnull(@Checks + nchar(13) + nchar(10), N'') +
				N'alter table ' + @Target + N' with check add constraint ' + quotename(N'CK_PartitionHoldRange_' + convert(nvarchar(20), @ObjectID)) + N' check (' + @Predicate + N');
alter table ' + @Target + N' switch to ' + @Source + N' partition ' + convert(nvarchar(20), @Fanout) + N';
drop table ' + @Target + N';
';
			fetch next from c into @ObjectID, @Source, @Target, @Column;
		end
		close c;
		deallocate c;
		-- Each boundary script declares @ID; execute in separate scopes inside the same transaction.
		select @SQL = string_agg(convert(nvarchar(max), N'exec sys.sp_executesql N''' + replace(SQL, N'''', N'''''') + N''';'), nchar(13) + nchar(10)) within group(order by Ordinal) from @Splits;
		insert into @Ret(Name, SQL, Action, PartitionNumber) values('Extend future boundaries', N'if @@trancount > 0 or @@options & 2 = 2
begin
	set xact_abort off;
	raiserror(''Partition maintenance requires no caller or implicit transaction.'', 16, 1);
	return;
end
set xact_abort on;
begin try
	begin tran;
' + @OutSQL + @SQL + nchar(13) + nchar(10) + @InSQL + N'commit;
end try
begin catch
	if @@trancount > 0 rollback;
	throw;
end catch;', 'ExtendBoundaries', @Fanout);
	end
	select @CompressionPartition = max(r.boundary_id) + 1 from sys.partition_range_values r
		outer apply z.fn_SqlVariantToDateTime(case when @BaseType = 'bigint' then r.value else convert(sql_variant, null) end) d
		where r.function_id = @FunctionID and @PartitionsToKeep >= 0 and
			case when @BaseType = 'bigint' then convert(datetime2(7), d.Value) else convert(datetime2(7), case when @BaseType <> 'bigint' then r.value end) end <= @FirstPeriodToKeep;
	declare b cursor local static for
		select r.boundary_id, r.value, case when @BaseType = 'bigint' then convert(datetime2(7), d.Value) else convert(datetime2(7), case when @BaseType <> 'bigint' then r.value end) end
		from sys.partition_range_values r outer apply z.fn_SqlVariantToDateTime(case when @BaseType = 'bigint' then r.value else convert(sql_variant, null) end) d
		where r.function_id = @FunctionID and @PartitionsToKeep >= 0 and
			case when @BaseType = 'bigint' then convert(datetime2(7), d.Value) else convert(datetime2(7), case when @BaseType <> 'bigint' then r.value end) end <= @FirstPeriodToKeep
		order by r.boundary_id desc;
	open b;
	fetch next from b into @BoundaryID, @Boundary, @BoundaryDate;
	while @@fetch_status = 0
	begin
		select @Suffix = convert(nvarchar(8), @BoundaryDate, 112) + case when @PartitionRangeType in ('Minute', 'Hourly') then N'_' + replace(convert(nvarchar(5), @BoundaryDate, 108), N':', N'') else N'' end,
			   @OutSQL = N'', @InSQL = N'', @MergeOutSQL = N'', @MergeInSQL = N'';
		if exists(select * from @Tables where len(TableName + N'_Partition_' + @Suffix) > 128 or len(Source) > 256
			or len(quotename(SchemaName) + N'.' + quotename(TableName + N'_Partition_' + @Suffix)) > 256)
			select @Error = N'Expired partition target name exceeds the supported identifier length.';
		else if exists(select * from @Tables where object_id(quotename(SchemaName) + N'.' + quotename(TableName + N'_Partition_' + @Suffix)) is not null)
			select @Error = N'Expired partition target already exists. Remove it explicitly before maintenance.';
		else if @ArchivedSwappedPartitions = 1 and exists(select * from @Tables) and exists(select * from @RetainedSuffixes where Suffix = @Suffix)
			select @Error = N'Expired boundaries produce duplicate retained table names at the configured period precision.';
		if @ArchivedSwappedPartitions = 1 and @Error is null and exists(select * from @Tables) insert into @RetainedSuffixes values(@Suffix);
		if @Right = 1 and @Error is null
		begin
			if exists(select * from @Tables where len(TableName + N'_Partition_MergeHold') > 128
				or len(quotename(SchemaName) + N'.' + quotename(TableName + N'_Partition_MergeHold')) > 256)
				select @Error = N'Partition merge holding name exceeds the supported identifier length.';
			else if exists(select * from @Tables where object_id(quotename(SchemaName) + N'.' + quotename(TableName + N'_Partition_MergeHold')) is not null)
				select @Error = N'Partition merge holding table already exists. Remove it explicitly before maintenance.';
			else if exists
			(
				select * from @Tables t join sys.indexes i on i.object_id = t.ObjectID
					join sys.partition_schemes s on s.data_space_id = i.data_space_id
					join sys.destination_data_spaces l on l.partition_scheme_id = s.data_space_id and l.destination_id = @BoundaryID
					join sys.destination_data_spaces r on r.partition_scheme_id = s.data_space_id and r.destination_id = @BoundaryID + 1
				where l.data_space_id <> r.data_space_id
			)
				select @Error = N'RIGHT expiration requires adjacent partitions on the same filegroup for each index.';
		end
		if @Error is not null
		begin
			delete from @Ret;
			insert into @Ret(Name, SQL, Action) values('Error', N'throw 50001, ' + quotename(@Error, '''') + N', 1;', 'Error');
			close b;
			deallocate b;
			return;
		end
		select @PreviousBoundary = null, @NextBoundary = null;
		select @PreviousBoundary = value from sys.partition_range_values where function_id = @FunctionID and boundary_id = @BoundaryID - 1;
		-- Higher expired boundaries are already merged when legacy callers execute this ordered queue.
		select top (1) @NextBoundary = r.value from sys.partition_range_values r
			outer apply z.fn_SqlVariantToDateTime(case when @BaseType = 'bigint' then r.value else convert(sql_variant, null) end) d
			where r.function_id = @FunctionID and r.boundary_id > @BoundaryID and
				case when @BaseType = 'bigint' then convert(datetime2(7), d.Value) else convert(datetime2(7), case when @BaseType <> 'bigint' then r.value end) end > @FirstPeriodToKeep
			order by r.boundary_id;
		if @NextBoundary is null and @FirstNewDate is not null
			select @NextBoundary = case when @BaseType = 'bigint' then convert(sql_variant, z.fn_GenerateZSequenceID(@FirstNewDate, 0)) else convert(sql_variant, @FirstNewDate) end;
		select @LowerLiteral = case when @PreviousBoundary is null then null when @BaseType = 'bigint' then convert(nvarchar(100), @PreviousBoundary)
			else N'convert(' + @DataType + N',convert(datetime2(7),' + quotename(convert(nvarchar(40), convert(datetime2(7), case when @BaseType <> 'bigint' then @PreviousBoundary end), 126), '''') + N',126))' end,
			@UpperLiteral = case when @NextBoundary is null then null when @BaseType = 'bigint' then convert(nvarchar(100), @NextBoundary)
			else N'convert(' + @DataType + N',convert(datetime2(7),' + quotename(convert(nvarchar(40), convert(datetime2(7), case when @BaseType <> 'bigint' then @NextBoundary end), 126), '''') + N',126))' end;
		declare t cursor local static for select ObjectID, Source, quotename(SchemaName) + N'.' + quotename(TableName + N'_Partition_' + @Suffix), ColumnName from @Tables order by Source;
		open t;
		fetch next from t into @ObjectID, @Source, @Target, @Column;
		while @@fetch_status = 0
		begin
			select @OutSQL += N'if object_id(' + (N'N''' + replace(@Target, N'''', N'''''') + N'''') + N') is not null throw 50001, N''Expired partition target already exists.'', 1;
exec z.usp_CopyTableSchema @FullSourceTableName = ' + (N'N''' + replace(@Source, N'''', N'''''') + N'''') + N', @FullTargetTableName = ' + (N'N''' + replace(@Target, N'''', N'''''') + N'''') + N', @PartitionNumber = ' + convert(nvarchar(20), @BoundaryID) + N', @DropTargetTableIfExists = 0, @CopyIdentity = 1;
alter table ' + @Source + N' switch partition ' + convert(nvarchar(20), @BoundaryID) + N' to ' + @Target + N';
';
			if @ArchivedSwappedPartitions = 0 select @InSQL += N'drop table ' + @Target + N';' + nchar(13) + nchar(10);
			if @Right = 1
			begin
				select @MergeTarget = quotename(object_schema_name(@ObjectID)) + N'.' + quotename(object_name(@ObjectID) + N'_Partition_MergeHold');
				select @MergeOutSQL += N'if object_id(' + (N'N''' + replace(@MergeTarget, N'''', N'''''') + N'''') + N') is not null throw 50001, N''Partition merge holding table already exists.'', 1;
exec z.usp_CopyTableSchema @FullSourceTableName = ' + (N'N''' + replace(@Source, N'''', N'''''') + N'''') + N', @FullTargetTableName = ' + (N'N''' + replace(@MergeTarget, N'''', N'''''') + N'''') + N', @PartitionNumber = ' + convert(nvarchar(20), @BoundaryID + 1) + N', @DropTargetTableIfExists = 0, @CopyIdentity = 1;
alter table ' + @Source + N' switch partition ' + convert(nvarchar(20), @BoundaryID + 1) + N' to ' + @MergeTarget + N';
';
				select @RestoreSQL = string_agg(convert(nvarchar(max), case when i.index_id = 0 then N'alter table ' + @Source
					else N'alter index ' + quotename(i.name) collate database_default + N' on ' + @Source end + N' rebuild partition = ' + convert(nvarchar(20), @BoundaryID)
					+ N' with (data_compression = ' + p.data_compression_desc collate database_default + N');'), nchar(13) + nchar(10)) within group(order by i.index_id)
					from sys.indexes i join sys.partitions p on p.object_id = i.object_id and p.index_id = i.index_id
					where i.object_id = @ObjectID and p.partition_number = @CompressionPartition and i.type in (0, 1, 2, 5, 6);
				select @Checks = string_agg(convert(nvarchar(max), N'alter table ' + @MergeTarget + N' with check add constraint ' +
					quotename(N'CK_PartitionMerge_' + convert(nvarchar(20), @ObjectID) + N'_' + convert(nvarchar(20), object_id)) + N' check ' + definition collate database_default + N';'), nchar(13) + nchar(10)) within group(order by object_id)
					from sys.check_constraints where parent_object_id = @ObjectID and is_disabled = 0;
				select @Predicate = case when @LowerLiteral is null then N'1 = 1' else quotename(@Column) + N' is not null and ' + quotename(@Column) + N' >= ' + @LowerLiteral end
					+ case when @UpperLiteral is null then N'' else N' and ' + quotename(@Column) + N' < ' + @UpperLiteral end;
				if @LowerLiteral is null select @Predicate = N'(' + @Predicate + N') or ' + quotename(@Column) + N' is null';
				select @MergeInSQL += isnull(@RestoreSQL + nchar(13) + nchar(10), N'') + isnull(@Checks + nchar(13) + nchar(10), N'') +
					N'alter table ' + @MergeTarget + N' with check add constraint ' + quotename(N'CK_PartitionMergeRange_' + convert(nvarchar(20), @ObjectID)) + N' check (' + @Predicate + N');
alter table ' + @MergeTarget + N' switch to ' + @Source + N' partition ' + convert(nvarchar(20), @BoundaryID) + N';
drop table ' + @MergeTarget + N';
';
			end
			fetch next from t into @ObjectID, @Source, @Target, @Column;
		end
		close t;
		deallocate t;
		select @UpperLiteral = case when @BaseType = 'bigint' then convert(nvarchar(100), @Boundary)
			else N'convert(' + @DataType + N',convert(datetime2(7),' + quotename(convert(nvarchar(40), convert(datetime2(7), @Boundary), 126), '''') + N',126))' end;
		insert into @Ret(Name, SQL, Action, PartitionNumber) values('Partition Swapout boundary ' + convert(varchar(40), @BoundaryDate, 126), N'if @@trancount > 0 or @@options & 2 = 2
begin
	set xact_abort off;
	raiserror(''Partition maintenance requires no caller or implicit transaction.'', 16, 1);
	return;
end
set xact_abort on;
begin try
	begin tran;
' + @OutSQL + @MergeOutSQL + N'alter partition function ' + quotename(@PartitionFunctionName) + N'() merge range (' + @UpperLiteral + N');
' + @MergeInSQL + @InSQL + N'commit;
end try
begin catch
	if @@trancount > 0 rollback;
	throw;
end catch;', 'ExpireBoundary', @BoundaryID);
		fetch next from b into @BoundaryID, @Boundary, @BoundaryDate;
	end
	close b;
	deallocate b;
	return;
end
go
