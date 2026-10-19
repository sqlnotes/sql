create or alter procedure z.usp_ForcePartitionRetentionPolicy
(
	@PartitionFunctionName nvarchar(128) = null,
	@ShowPlan bit = 0
)
as
begin
	set nocount on;
	-- Disable XACT_ABORT before rejection to preserve caller transaction committability.
	if isnull(@ShowPlan, 0) = 0 and (@@trancount > 0 or @@options & 2 = 2)
	begin
		set xact_abort off;
		throw 50000, N'Partition maintenance cannot execute in a caller-owned or implicit transaction.', 1;
	end
	declare @ImplicitTransactions bit = iif(@@options & 2 = 2, 1, 0), @XactAbort bit = iif(@@options & 16384 = 16384, 1, 0),
			@FunctionName nvarchar(128), @ActualName nvarchar(128), @Period varchar(20), @Interval int,
			@Forward int, @FileGroup nvarchar(128), @Keep int, @Retain bit, @Today datetime = getutcdate(),
			@SQL nvarchar(max), @Action varchar(30), @LockResource nvarchar(255), @LockResult int,
			@Locked bit = 0, @Failures nvarchar(max) = N'', @Error nvarchar(2048),
			@Source nvarchar(517), @Target nvarchar(517), @Number int, @ObjectID int, @PreviousFanout int, @CurrentFanout int;
	if @ShowPlan is null
	begin
		set xact_abort off;
		throw 50000, N'ShowPlan must be specified.', 1;
	end
	-- Preview may run inside a transaction, but must not start an implicit one.
	if @ShowPlan = 1
	begin
		set implicit_transactions off;
		set xact_abort off;
	end
	else set xact_abort on;
	create table #PartitionPlan (Ordinal int, Name varchar(300), SQL nvarchar(max), Action varchar(30), TableName nvarchar(517), PartitionNumber int);
	create table #PartitionPreview (PartitionFunctionName nvarchar(128), Ordinal int, Action varchar(30), TableName nvarchar(517), PartitionNumber int, SQL nvarchar(max));
	create table #PartitionCopyPreview (Ordinal int, PartName varchar(30), Definition nvarchar(max));
	if @PartitionFunctionName is not null and not exists(select * from z.PartitionedTableDataRetention where PartitionFunctionName = @PartitionFunctionName)
	begin
		if @ShowPlan = 1
		begin
			select @PartitionFunctionName PartitionFunctionName, 0 Ordinal, convert(varchar(30), 'Error') Action,
				convert(nvarchar(517), null) TableName, convert(int, null) PartitionNumber,
				convert(nvarchar(max), N'throw 50001, N''No retention policy exists for the selected partition function.'', 1;') SQL;
			if @XactAbort = 1 set xact_abort on;
			if @ImplicitTransactions = 1 set implicit_transactions on;
			return;
		end
		if @ImplicitTransactions = 1 set implicit_transactions on;
		throw 50001, N'No retention policy exists for the selected partition function.', 1;
	end
	declare f cursor local static for
		select PartitionFunctionName, PartitionRangeType, PartitionRangeTypeInterval, ForwardedPartitionCount,
			   NextPartitionFileGroup, PartitionsToKeep, ArchivedSwappedPartitions
		from z.PartitionedTableDataRetention
		where @PartitionFunctionName is null or PartitionFunctionName = @PartitionFunctionName
		order by PartitionFunctionName;
	open f;
	fetch next from f into @FunctionName, @Period, @Interval, @Forward, @FileGroup, @Keep, @Retain;
	while @@fetch_status = 0
	begin
		select @Locked = 0, @Action = 'Validate', @ActualName = null;
		begin try
			select @ActualName = name from sys.partition_functions where name = @FunctionName;
			select @LockResource = N'SchemaZ.Partition:' + isnull(@ActualName, @FunctionName);
			if @ShowPlan = 0
			begin
				exec @LockResult = sys.sp_getapplock @Resource = @LockResource, @LockMode = 'Exclusive', @LockOwner = 'Session', @LockTimeout = 0;
				if @LockResult < 0 throw 50001, N'Partition function maintenance lock is unavailable.', 1;
				select @Locked = 1;
			end
			while 1 = 1
			begin
				truncate table #PartitionPlan;
				insert into #PartitionPlan
					select Ordinal, Name, SQL, Action, TableName, PartitionNumber
					from z.fn_BuildQueryForcePartitionRetentionPolicy(@FunctionName, @Period, @Interval, @Forward, @FileGroup, @Keep, @Retain, @Today);
				if exists(select * from #PartitionPlan where Action = 'Error')
				begin
					if @ShowPlan = 1
					begin
						insert into #PartitionPreview select @FunctionName, Ordinal, Action, TableName, PartitionNumber, SQL from #PartitionPlan;
						break;
					end
					select top (1) @SQL = SQL from #PartitionPlan where Action = 'Error' order by Ordinal;
					exec sys.sp_executesql @SQL;
				end
				-- Execute-only preflight avoids nested INSERT EXEC for callers capturing preview.
				if @ShowPlan = 0
				begin
					declare v cursor local static for
						select distinct i.object_id, quotename(object_schema_name(i.object_id)) + N'.' + quotename(object_name(i.object_id)), n.Number
						from sys.indexes i join sys.partition_schemes s on s.data_space_id = i.data_space_id
							join sys.partition_functions pf on pf.function_id = s.function_id cross join #PartitionPlan p
							cross apply(values(p.PartitionNumber), (case when p.Action = 'ExpireBoundary' and pf.boundary_value_on_right = 1 then p.PartitionNumber + 1 end)) n(Number)
						where pf.name = @FunctionName and i.index_id in (0, 1) and n.Number is not null and p.Action in ('ExtendBoundaries', 'ExpireBoundary');
					open v;
					fetch next from v into @ObjectID, @Source, @Number;
					while @@fetch_status = 0
					begin
						select @Target = quotename(object_schema_name(@ObjectID)) + N'.' + quotename(N'PartitionPreview_' + convert(nvarchar(20), @ObjectID));
						truncate table #PartitionCopyPreview;
						insert into #PartitionCopyPreview
							exec z.usp_CopyTableSchema @FullSourceTableName = @Source, @FullTargetTableName = @Target,
								@PartitionNumber = @Number, @DropTargetTableIfExists = 0, @CopyIdentity = 1, @ShowPlan = 1;
						fetch next from v into @ObjectID, @Source, @Number;
					end
					close v;
					deallocate v;
				end
				if @ShowPlan = 1
				begin
					insert into #PartitionPreview select @FunctionName, Ordinal, Action, TableName, PartitionNumber, SQL from #PartitionPlan;
					break;
				end
				select @SQL = null;
				select top (1) @SQL = SQL, @Action = Action from #PartitionPlan order by Ordinal;
				if @SQL is null break;
				select @PreviousFanout = fanout from sys.partition_functions where name = @FunctionName;
				exec sys.sp_executesql @SQL;
				select @CurrentFanout = fanout from sys.partition_functions where name = @FunctionName;
				if @CurrentFanout = @PreviousFanout
					throw 50001, N'Partition maintenance made no boundary progress; refusing to repeat the action.', 1;
				-- Regenerate against committed metadata after every atomic action.
			end
		end try
		begin catch
			if cursor_status('local', 'v') >= 0 close v;
			if cursor_status('local', 'v') > -3 deallocate v;
			if @ShowPlan = 0 and @@trancount > 0 rollback;
			select @Error = left(concat(N'Partition function ', quotename(@FunctionName), N', action ', @Action, N': ', error_message()), 2048);
			select @Failures += @Error + nchar(13) + nchar(10);
			if @ShowPlan = 1
				insert into #PartitionPreview values(@FunctionName, 0, 'Error', null, null, N'throw 50001, N''' + replace(@Error, N'''', N'''''') + N''', 1;');
		end catch
		if @Locked = 1
		begin
			exec @LockResult = sys.sp_releaseapplock @Resource = @LockResource, @LockOwner = 'Session';
			select @Locked = 0;
		end
		fetch next from f into @FunctionName, @Period, @Interval, @Forward, @FileGroup, @Keep, @Retain;
	end
	close f;
	deallocate f;
	if @ShowPlan = 1
		select PartitionFunctionName, Ordinal, Action, TableName, PartitionNumber, SQL from #PartitionPreview order by PartitionFunctionName, Ordinal;
	else if @Failures <> N''
	begin
		select @Error = left(@Failures, 2048);
		throw 50001, @Error, 1;
	end
	if @ImplicitTransactions = 1 set implicit_transactions on;
	if @ShowPlan = 1 and @XactAbort = 1 set xact_abort on;
end
go
