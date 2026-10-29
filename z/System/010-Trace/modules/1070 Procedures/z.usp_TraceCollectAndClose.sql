create or alter procedure z.usp_TraceCollectAndClose
(
	@MaxDurationInSec int = 2147483647,
	@TransactionDurationInSec int = 2,
	@MaxEventsPerTransaction int = 300
)
as
begin
	set nocount on;
	if @@trancount > 0
	begin
		set xact_abort off;
		throw 50000, N'Trace collection requires no existing transaction.', 1;
	end;
	set xact_abort on;
	set textsize 2147483647;
	set cursor_close_on_commit off;
	if @MaxDurationInSec is null or @MaxDurationInSec < 0 or @TransactionDurationInSec is null or @TransactionDurationInSec < 1
		or @MaxEventsPerTransaction is null or @MaxEventsPerTransaction < 1
		throw 50000, N'Capture duration must be nonnegative; transaction duration and event limit must be positive.', 1;
	exec z.usp_TraceAssertOwner;
	declare @CollectorUUID uniqueidentifier = try_convert(uniqueidentifier, session_context(N'Schema z.TraceCollector.UUID')),
		@SQL nvarchar(max), @Declarations nvarchar(max), @Reset nvarchar(max), @Decode nvarchar(max),
		@Routes nvarchar(max) = N'', @ColumnNames nvarchar(max), @Values nvarchar(max), @Events nvarchar(max),
		@TraceID int, @ReceivingTable nvarchar(128), @Callback nvarchar(517), @EventName nvarchar(128),
		@ColumnID int, @PreviousColumnID int, @FilterOrdinal int, @LogicOperator varchar(3), @ComparisonOperator varchar(8),
		@Definition nvarchar(128), @Variable nvarchar(64), @Expression nvarchar(max), @Group nvarchar(max), @Predicate nvarchar(max),
		@LockResult int, @Resource nvarchar(255);
	if not exists(select 1 from z.TraceCollector where CollectorUUID = @CollectorUUID and State = 'Building')
		throw 50000, N'The collector is already collecting.', 1;
	select TraceID, ReceivingTable into #LogicalTrace from z.Trace where CollectorUUID = @CollectorUUID and IsEnabled = 1;
	if not exists(select 1 from #LogicalTrace)
	begin
		print N'No enabled logical trace found.';
		return;
	end;
	select e.TraceID, e.EventID into #LogicalEvent from z.TraceEvent e inner join #LogicalTrace t on t.TraceID = e.TraceID;
	select c.TraceID, c.EventID, c.ColumnID into #LogicalColumn from z.TraceEventColumn c inner join #LogicalTrace t on t.TraceID = c.TraceID;
	select f.* into #LogicalFilter from z.TraceFilter f inner join #LogicalTrace t on t.TraceID = f.TraceID;
	select g.* into #LogicalTrigger from z.TraceTrigger g inner join #LogicalTrace t on t.TraceID = g.TraceID;
	select ColumnID, ColumnName, DataType, Definition into #Columns from z.v_TraceColumn;
	create unique clustered index IX_LogicalFilter on #LogicalFilter(TraceID, FilterOrdinal);
	create unique clustered index IX_LogicalColumn on #LogicalColumn(TraceID, EventID, ColumnID);
	create unique clustered index IX_LogicalEvent on #LogicalEvent(TraceID, EventID);
	begin try
		if exists(select 1 from #LogicalTrace t where not exists(select 1 from #LogicalEvent e where e.TraceID = t.TraceID))
			throw 50000, N'Every enabled logical trace must select an event.', 1;
		if exists
		(
			select 1 from #LogicalTrigger g
			where object_id(g.ProcedureName, N'P') is null or parsename(g.ProcedureName, 2) is null or parsename(g.ProcedureName, 3) is not null
				or exists(select 1 from (values(N'@TraceSequence'),(N'@TraceID'),(N'@EventName')) p(Name)
					where not exists(select 1 from sys.parameters s where s.object_id = object_id(g.ProcedureName, N'P') and s.name = p.Name))
		)
			throw 50000, N'Trace callbacks must be existing two-part procedures accepting @TraceSequence, @TraceID and @EventName.', 1;
		-- Hold the destination lock for DDL only, never for collection.
		declare d cursor local static for select distinct ReceivingTable from #LogicalTrace order by ReceivingTable;
		open d;
		fetch next from d into @ReceivingTable;
		while @@fetch_status = 0
		begin
			select @Resource = N'Schema z.TraceReceiver:' + convert(nvarchar(20), checksum(@ReceivingTable collate database_default));
			begin tran;
			exec @LockResult = sys.sp_getapplock @Resource = @Resource, @LockMode = N'Exclusive', @LockOwner = N'Transaction', @LockTimeout = 30000;
			if @LockResult < 0 throw 50000, N'Could not prepare the trace receiving table.', 1;
			if object_id(@ReceivingTable) is not null and object_id(@ReceivingTable, N'U') is null
				throw 50000, N'A trace receiving destination must be a table.', 1;
			if object_id(@ReceivingTable, N'U') is not null and
			(
				select count(*) from sys.columns where object_id = object_id(@ReceivingTable)
					and is_computed = 0 and is_identity = 0 and is_nullable = 0
					and ((name = N'TraceSequence' and system_type_id = 127)
						or (name = N'EventID' and system_type_id = 56)
						or (name = N'EventName' and system_type_id = 231 and (max_length = -1 or max_length >= 256)))
			) <> 3
				throw 50000, N'Trace receiving tables require noncomputed, nonidentity, nonnullable TraceSequence bigint, EventID int and EventName nvarchar(128) or wider.', 1;
			if object_id(@ReceivingTable, N'U') is null
			begin
				select @SQL = N'create table ' + @ReceivingTable + N' (TraceSequence bigint not null constraint ' + quotename(N'DF_TraceReceiver_' + replace(convert(nvarchar(36), newid()), N'-', N''))
					+ N' default(datediff_big(second, ''19000101'', getutcdate()) * 268435456 | next value for z.SeqGeneralID), EventID int not null, EventName nvarchar(128) not null, constraint '
					+ quotename(N'PK_TraceReceiver_' + replace(convert(nvarchar(36), newid()), N'-', N'')) + N' primary key clustered(TraceSequence) with (data_compression = page) on PS_SchemaZPartitionGeneric(TraceSequence)) on PS_SchemaZPartitionGeneric(TraceSequence);';
				exec sys.sp_executesql @SQL;
			end;
			declare c cursor local fast_forward for select ColumnName, Definition from #Columns order by ColumnID;
			open c;
			fetch next from c into @EventName, @Definition;
			while @@fetch_status = 0
			begin
				if not exists(select 1 from sys.columns where object_id = object_id(@ReceivingTable) and name = @EventName)
				begin
					select @SQL = N'alter table ' + @ReceivingTable + N' add ' + quotename(@EventName) + N' ' + @Definition + N' null;';
					exec sys.sp_executesql @SQL;
				end;
				fetch next from c into @EventName, @Definition;
			end;
			close c;
			deallocate c;
			exec z.usp_ForceNamingConvention @ReceivingTable;
			commit;
			fetch next from d into @ReceivingTable;
		end;
		close d;
		deallocate d;
		select @Declarations = (select N', @C' + convert(nvarchar(10), ColumnID) + N' ' + Definition from #Columns order by ColumnID for xml path(''), type).value('.', 'nvarchar(max)'),
			@Reset = (select N', @C' + convert(nvarchar(10), ColumnID) + N' = null' from #Columns order by ColumnID for xml path(''), type).value('.', 'nvarchar(max)'),
			@ColumnNames = (select N', ' + quotename(ColumnName) from #Columns order by ColumnID for xml path(''), type).value('.', 'nvarchar(max)');
		select @Decode =
		(
			select N'
				' + case when row_number() over(order by ColumnID) = 1 then N'if' else N'else if' end + N' @ColumnID = ' + convert(nvarchar(10), ColumnID) + N'
					select @C' + convert(nvarchar(10), ColumnID) + N' = ' +
				case DataType
					when 'bigint' then N'convert(bigint, convert(binary(8), reverse(substring(@Data, 1, 8))))'
					when 'int' then N'convert(int, convert(binary(4), reverse(substring(@Data, 1, 4))))'
					when 'datetime' then N'convert(datetime, convert(varchar(10), Y) + ''-'' + right(''00'' + convert(varchar(2), M), 2) + ''-'' + right(''00'' + convert(varchar(2), D), 2) + '' '' + right(''00'' + convert(varchar(2), HH), 2) + '':'' + right(''00'' + convert(varchar(2), MM), 2) + '':'' + right(''00'' + convert(varchar(2), SS), 2) + ''.'' + right(''000'' + convert(varchar(3), MS), 3), 121)
					from (select convert(int, convert(binary(2), reverse(substring(@Data, 1, 2)))) Y, convert(int, convert(binary(2), reverse(substring(@Data, 3, 2)))) M,
						convert(int, convert(binary(2), reverse(substring(@Data, 7, 2)))) D, convert(int, convert(binary(2), reverse(substring(@Data, 9, 2)))) HH,
						convert(int, convert(binary(2), reverse(substring(@Data, 11, 2)))) MM, convert(int, convert(binary(2), reverse(substring(@Data, 13, 2)))) SS,
						convert(int, convert(binary(2), reverse(substring(@Data, 15, 2)))) MS) d'
					else N'convert(' + Definition + N', @Data)'
				end + N';'
			from #Columns order by ColumnID for xml path(''), type
		).value('.', 'nvarchar(max)');
		declare r cursor local static for select TraceID, ReceivingTable from #LogicalTrace order by TraceID;
		open r;
		fetch next from r into @TraceID, @ReceivingTable;
		while @@fetch_status = 0
		begin
			select @Predicate = N'', @Group = N'', @PreviousColumnID = null;
			declare f cursor local static for
				select f.ColumnID, f.FilterOrdinal, f.LogicOperator, f.ComparisonOperator, c.Definition
				from #LogicalFilter f inner join #Columns c on c.ColumnID = f.ColumnID
				where f.TraceID = @TraceID order by f.ColumnID, f.FilterOrdinal;
			open f;
			fetch next from f into @ColumnID, @FilterOrdinal, @LogicOperator, @ComparisonOperator, @Definition;
			while @@fetch_status = 0
			begin
				select @Variable = N'@F' + convert(nvarchar(10), @TraceID) + N'_' + convert(nvarchar(10), @FilterOrdinal);
				select @Declarations += N'; declare ' + @Variable + N' ' + @Definition + N'; select ' + @Variable + N' = convert(' + @Definition + N', Value) from #LogicalFilter where TraceID = ' + convert(nvarchar(10), @TraceID) + N' and FilterOrdinal = ' + convert(nvarchar(10), @FilterOrdinal);
				if @PreviousColumnID is not null and @PreviousColumnID <> @ColumnID
					select @Predicate += N' and (' + @Group + N')', @Group = N'';
				select @Expression = N'@C' + convert(nvarchar(10), @ColumnID) + N' ' + case when @ComparisonOperator = 'notlike' then N'not like' else @ComparisonOperator end + N' ' + @Variable;
				select @Group = case when @Group = N'' then @Expression else N'(' + @Group + N' ' + @LogicOperator + N' ' + @Expression + N')' end, @PreviousColumnID = @ColumnID;
				fetch next from f into @ColumnID, @FilterOrdinal, @LogicOperator, @ComparisonOperator, @Definition;
			end;
			close f;
			deallocate f;
			if @Group <> N'' select @Predicate += N' and (' + @Group + N')';
			select @Events = string_agg(convert(nvarchar(max), EventID), N',') within group(order by EventID) from #LogicalEvent where TraceID = @TraceID;
			select @Values =
			(
				select N', ' + case when exists(select 1 from #LogicalColumn b where b.TraceID = @TraceID and b.ColumnID = c.ColumnID)
					then N'case when @EventID in (' + (select string_agg(convert(nvarchar(max), EventID), N',') within group(order by EventID) from #LogicalColumn b where b.TraceID = @TraceID and b.ColumnID = c.ColumnID) + N') then @C' + convert(nvarchar(10), c.ColumnID) + N' end'
					else N'null' end
				from #Columns c order by c.ColumnID for xml path(''), type
			).value('.', 'nvarchar(max)');
			select @Routes += N'
				if @EventID in (' + @Events + N')' + @Predicate + N'
					and exists(select 1 from z.Trace where TraceID = ' + convert(nvarchar(10), @TraceID) + N' and CollectorUUID = @CollectorUUID and IsEnabled = 1)
				begin
					if @@trancount = 0
					begin
						begin tran;
						select @BatchStarted = sysutcdatetime(), @BatchCount = 0;
					end;
					select @TraceSequence = datediff_big(second, ''19000101'', getutcdate()) * 268435456 | next value for z.SeqGeneralID;
					insert ' + @ReceivingTable + N' (TraceSequence, EventID, EventName' + @ColumnNames + N')
						values (@TraceSequence, @EventID, @EventName' + @Values + N');';
			declare g cursor local static for
				select EventName, quotename(parsename(ProcedureName, 2)) + N'.' + quotename(parsename(ProcedureName, 1))
				from #LogicalTrigger where TraceID = @TraceID
					and (EventName = N'all' or not exists(select 1 from #LogicalTrigger where TraceID = @TraceID and EventName = N'all'))
				order by EventName;
			open g;
			fetch next from g into @EventName, @Callback;
			while @@fetch_status = 0
			begin
				select @Routes += N'
					' + case when @EventName = N'all' then N'' else N'if @EventName = N' + quotename(@EventName, '''') + N' ' end
					+ N'exec ' + @Callback + N' @TraceSequence = @TraceSequence, @TraceID = ' + convert(nvarchar(10), @TraceID) + N', @EventName = @EventName;';
				fetch next from g into @EventName, @Callback;
			end;
			close g;
			deallocate g;
			select @Routes += N'
				end;';
			fetch next from r into @TraceID, @ReceivingTable;
		end;
		close r;
		deallocate r;
		-- Cache typed filters and compiled routes once, outside the reception loop.
		select @SQL = N'declare @EventID int, @EventName nvarchar(128), @ColumnID int, @Data varbinary(max), @TraceSequence bigint,
	@BatchCount int = 0, @BatchStarted datetime2(7), @ReadEvents int, @FetchStatus int, @FrameLength int,
	@NativeTraceID int, @NativeStartTime datetime, @NativeStopTime datetime, @RetiredTraceID int, @RetiredStartTime datetime, @RetiredStopTime datetime,
	@NextStopTime datetime = getdate(), @GenerationStartedUTC datetime2(7), @OldestGenerationUTC datetime2(7),
	@CaptureUntil datetime = dateadd(second, @MaxDurationInSec, getdate()), @CoverageUntil datetime,
	@WindowSeconds int = 2, @CaptureAhead int = 4, @CreateCount int, @HaveBuffer bit = 0' + @Declarations + N';
create table #Buffer (Ordinal bigint identity(1,1) not null, ColumnID int, FrameLength int, Data varbinary(max));
create unique clustered index IX_Buffer on #Buffer(Ordinal);
create table #Generations (TraceID int not null, NativeStartTime datetime not null, NativeStopTime datetime not null, StartedUTC datetime2(7) not null);
create unique clustered index IX_Generations on #Generations(TraceID, NativeStopTime);
create table #Seen (EventSequence bigint not null, SeenUTC datetime2(7) not null);
create unique clustered index IX_Seen on #Seen(EventSequence);
if @MaxDurationInSec = 0 select @CoverageUntil = @CaptureUntil;
begin try
	while @HaveBuffer = 1 or @CoverageUntil is null or @CoverageUntil < @CaptureUntil
	begin
		if not exists(select 1 from z.Trace where CollectorUUID = @CollectorUUID and IsEnabled = 1) break;
		if @CoverageUntil is null or @CoverageUntil < @CaptureUntil
		begin
			-- Retire only our stopped generations; another generation keeps capturing.
			declare cRetired cursor local static read_only for
				select g.TraceID, g.NativeStartTime, g.NativeStopTime
				from #Generations g left join sys.traces n on n.id = g.TraceID
				where n.id is null or (n.start_time = g.NativeStartTime and n.stop_time = g.NativeStopTime and n.status = 0);
			open cRetired;
			fetch next from cRetired into @RetiredTraceID, @RetiredStartTime, @RetiredStopTime;
			while @@fetch_status = 0
			begin
				begin try
					if exists(select 1 from sys.traces where id = @RetiredTraceID and start_time = @RetiredStartTime and stop_time = @RetiredStopTime and status = 0)
						exec sys.sp_trace_setstatus @RetiredTraceID, 2;
				end try
				begin catch
					if exists(select 1 from sys.traces where id = @RetiredTraceID and start_time = @RetiredStartTime and stop_time = @RetiredStopTime) throw;
				end catch;
				if not exists(select 1 from sys.traces where id = @RetiredTraceID and start_time = @RetiredStartTime and stop_time = @RetiredStopTime)
				begin
					delete z.TraceCollectorTrace where CollectorUUID = @CollectorUUID and TraceID = @RetiredTraceID and NativeStopTime = @RetiredStopTime;
					delete #Generations where TraceID = @RetiredTraceID and NativeStopTime = @RetiredStopTime;
				end;
				fetch next from cRetired into @RetiredTraceID, @RetiredStartTime, @RetiredStopTime;
			end;
			close cRetired;
			deallocate cRetired;
			select @CreateCount = @CaptureAhead - count(*)
			from #Generations g inner join sys.traces n on n.id = g.TraceID and n.start_time = g.NativeStartTime and n.stop_time = g.NativeStopTime
			where n.status = 1 and n.stop_time > dateadd(millisecond, 250, getdate());
			while @CreateCount > 0
			begin
				if not exists(select 1 from z.Trace where CollectorUUID = @CollectorUUID and IsEnabled = 1) break;
				select @NextStopTime = dateadd(second, @WindowSeconds, @NextStopTime), @GenerationStartedUTC = sysutcdatetime();
				if @NextStopTime < dateadd(second, @WindowSeconds, getdate()) select @NextStopTime = dateadd(second, @WindowSeconds, getdate());
				exec z.usp_TraceOpenPhysical @NativeTraceID output, @StopAt = @NextStopTime;
				if @NativeTraceID is null break;
				insert #Generations (TraceID, NativeStartTime, NativeStopTime, StartedUTC)
					select TraceID, NativeStartTime, NativeStopTime, @GenerationStartedUTC from z.TraceCollectorTrace
					where CollectorUUID = @CollectorUUID and TraceID = @NativeTraceID and NativeStopTime = @NextStopTime;
				select @CreateCount -= 1;
			end;
		end;
		if not exists(select 1 from z.Trace where CollectorUUID = @CollectorUUID and IsEnabled = 1) break;
		if @HaveBuffer = 0
		begin
			select @NativeTraceID = null;
			select top (1) @NativeTraceID = g.TraceID, @NativeStartTime = g.NativeStartTime, @NativeStopTime = g.NativeStopTime
			from #Generations g inner join sys.traces n on n.id = g.TraceID and n.start_time = g.NativeStartTime and n.stop_time = g.NativeStopTime
			where n.status = 1 and n.stop_time > dateadd(millisecond, 250, getdate())
			order by case when @CoverageUntil is null or g.NativeStartTime <= @CoverageUntil then 0 else 1 end, g.NativeStopTime;
			if @NativeTraceID is null continue;
			truncate table #Buffer;
			insert #Buffer (ColumnID, FrameLength, Data) exec sys.sp_trace_getdata @NativeTraceID, 0;
			select @CoverageUntil = @NativeStopTime, @HaveBuffer = 1;
			continue;
		end;
		select @ReadEvents = 0, @EventID = null, @EventName = null;
		declare cTraceBuffer cursor local static read_only for select ColumnID, FrameLength, Data from #Buffer order by Ordinal;
		open cTraceBuffer;
		fetch next from cTraceBuffer into @ColumnID, @FrameLength, @Data;
		select @FetchStatus = @@fetch_status;
		while @FetchStatus = 0
		begin
			if @ColumnID = 65526
			begin
				select @EventID = convert(int, convert(binary(2), reverse(substring(@Data, 1, 2)))), @EventName = null' + @Reset + N';
				select @EventName = case @EventID' + (select N' when ' + convert(nvarchar(10), TraceEventID) + N' then N' + quotename(EventName, '''') from z.v_TraceEvent order by TraceEventID for xml path(''), type).value('.', 'nvarchar(max)') + N' end;
			end
			else if @EventName is not null
			begin' + @Decode + N'
			end;
			-- Keep the next row pending while the completed event is delivered.
			fetch next from cTraceBuffer into @ColumnID, @FrameLength, @Data;
			-- Callbacks can use cursors, so preserve this cursor status before invoking them.
			select @FetchStatus = @@fetch_status;
			if @EventName is not null and (@FetchStatus <> 0 or @ColumnID = 65526)
				and (@C51 is null or not exists(select 1 from #Seen where EventSequence = @C51))
			begin
				if @C51 is not null insert #Seen (EventSequence, SeenUTC) values (@C51, sysutcdatetime());
				-- EventClass comes from the frame header even when no column-27 field is returned.
				select @C27 = @EventID, @ReadEvents += 1;
' + @Routes + N'
				if @@trancount > 0
				begin
					select @BatchCount += 1;
					if @BatchCount >= @MaxEventsPerTransaction or datediff_big(millisecond, @BatchStarted, sysutcdatetime()) >= convert(bigint, @TransactionDurationInSec) * 1000
					begin
						commit;
						select @BatchCount = 0, @BatchStarted = null;
					end;
				end;
			end;
		end;
		close cTraceBuffer;
		deallocate cTraceBuffer;
		if @@trancount > 0 commit;
		select @BatchCount = 0, @BatchStarted = null, @HaveBuffer = 0;
		-- Once all retained generations started later, an old event cannot reappear in their overlap.
		select @OldestGenerationUTC = min(g.StartedUTC)
		from #Generations g inner join sys.traces n on n.id = g.TraceID and n.start_time = g.NativeStartTime and n.stop_time = g.NativeStopTime
		where n.status = 1;
		if @OldestGenerationUTC is not null delete #Seen where SeenUTC < dateadd(second, -1, @OldestGenerationUTC);
	end;
end try
begin catch
	if @@trancount > 0 rollback;
	begin try
		if cursor_status(''local'', ''cTraceBuffer'') >= 0 close cTraceBuffer;
		if cursor_status(''local'', ''cTraceBuffer'') >= -1 deallocate cTraceBuffer;
		if cursor_status(''local'', ''cRetired'') >= 0 close cRetired;
		if cursor_status(''local'', ''cRetired'') >= -1 deallocate cRetired;
	end try
	begin catch
		print N''Trace buffer cursor cleanup failed.'';
	end catch;
	throw;
end catch;';
		exec sys.sp_executesql @SQL,
			N'@MaxDurationInSec int, @TransactionDurationInSec int, @MaxEventsPerTransaction int, @CollectorUUID uniqueidentifier',
			@MaxDurationInSec, @TransactionDurationInSec, @MaxEventsPerTransaction, @CollectorUUID;
		exec z.usp_TraceClose;
	end try
	begin catch
		if @@trancount > 0 rollback;
		begin try
			if exists(select 1 from z.TraceCollector where CollectorUUID = @CollectorUUID) exec z.usp_TraceClose;
		end try
		begin catch
			print N'Trace cleanup failed; retained ownership requires review.';
		end catch;
		throw;
	end catch;
end;
go
