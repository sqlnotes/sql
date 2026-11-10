/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/010-Trace/modules/1070%20Procedures/z.usp_TraceCollectAndClose.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/010-Trace/docs/reference/z.usp_TraceCollectAndClose.md

Collects selected native traces and closes them when collection finishes.
*/
create or alter procedure z.usp_TraceCollectAndClose
(
	@MaxDurationInSec int = 2147483647,
	@TransactionDurationInSec int = 5,
	@MaxEventsPerTransaction int = null,
	@TraceName nvarchar(128) = null,
	@TraceID int = null
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
		or @MaxEventsPerTransaction < 1
		throw 50000, N'Capture duration must be nonnegative; transaction duration and an optional event limit must be positive.', 1;
	declare @SQL nvarchar(max), @Declarations nvarchar(max), @Reset nvarchar(max), @Decode nvarchar(max),
		@Routes nvarchar(max) = N'', @ColumnNames nvarchar(max), @Values nvarchar(max),
		@ReceivingTable nvarchar(517), @Callback nvarchar(517), @EventName nvarchar(128), @Definition nvarchar(128), @CleanupLoginTime datetime,
		@LockResult int, @Resource nvarchar(255),
		@CreatorLoginTime datetime = (select login_time from sys.dm_exec_sessions where session_id = @@spid);
	select t.TraceID, t.Name, t.ReceivingTable, t.CreatorLoginTime into #Traces
	from z.Trace t inner join sys.traces n on n.id = t.TraceID and n.stop_time is null and n.is_rowset = 1
	where t.CreatorSessionID = @@spid and t.CreatorLoginTime = @CreatorLoginTime and n.status = 1
		and (@TraceName is null or t.Name = @TraceName) and (@TraceID is null or t.TraceID = @TraceID);
	if not exists(select 1 from #Traces)
	begin
		print N'No running trace matched the current session and selectors.';
		return;
	end;
	-- This immutable selection also scopes normal and error cleanup.
	select * into #CleanupTraces from #Traces;
	select c.TraceID, c.EventID, c.ColumnID into #SelectedColumns
	from z.TraceEventColumn c inner join #Traces t on t.TraceID = c.TraceID;
	select g.* into #Callbacks from z.TraceTrigger g inner join #Traces t on t.TraceID = g.TraceID;
	select ColumnID, ColumnName, DataType, Definition into #Columns from z.v_TraceColumn
	where ColumnID = 27 or ColumnID in (select ColumnID from #SelectedColumns);
	begin try
		if exists
		(
			select 1 from #Callbacks g
			where object_id(g.ProcedureName, N'P') is null or parsename(g.ProcedureName, 2) is null or parsename(g.ProcedureName, 3) is not null
				or exists(select 1 from (values(N'@TraceSequence'),(N'@TraceID'),(N'@EventName')) p(Name)
					where not exists(select 1 from sys.parameters s where s.object_id = object_id(g.ProcedureName, N'P') and s.name = p.Name))
		)
			throw 50000, N'Trace callbacks must be existing two-part procedures accepting @TraceSequence, @TraceID and @EventName.', 1;
		-- Hold the destination lock for DDL only, never for collection.
		declare d cursor local static for select distinct ReceivingTable from #Traces order by ReceivingTable;
		open d;
		fetch next from d into @ReceivingTable;
		while @@fetch_status = 0
		begin
			if parsename(@ReceivingTable, 2) is null or parsename(@ReceivingTable, 3) is not null or parsename(@ReceivingTable, 4) is not null
				throw 50000, N'Trace receiving tables must use two-part names in the current database.', 1;
			select @Resource = N'Schema z.TraceReceiver:' + convert(nvarchar(20), checksum(@ReceivingTable collate database_default));
			begin tran;
			exec @LockResult = z.usp_AcquireSemaphore @SemaphoreName = @Resource, @TotalCount = 1, @LockOwner = N'Transaction', @LockTimeout = 30000;
			if @LockResult <= 0 throw 50000, N'Could not prepare the trace receiving table.', 1;
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
				select @SQL = N'create table ' + quotename(parsename(@ReceivingTable, 2)) + N'.' + quotename(parsename(@ReceivingTable, 1)) + N' (TraceSequence bigint not null constraint ' + quotename(N'DF_TraceReceiver_' + replace(convert(nvarchar(36), newid()), N'-', N''))
					+ N' default(datediff_big(second, ''1900-01-01'', getutcdate()) * 268435456 | next value for z.SeqGeneralID), EventID int not null, EventName nvarchar(128) not null, constraint '
					+ quotename(N'PK_TraceReceiver_' + replace(convert(nvarchar(36), newid()), N'-', N'')) + N' primary key clustered(TraceSequence) with (data_compression = page) on PS_SchemaZPartitionGeneric(TraceSequence)) on PS_SchemaZPartitionGeneric(TraceSequence);';
				exec sys.sp_executesql @SQL;
			end;
			declare c cursor local fast_forward for select c.ColumnName, c.Definition from #Columns c
				where exists(select 1 from #SelectedColumns b inner join #Traces t on t.TraceID = b.TraceID
					where t.ReceivingTable = @ReceivingTable and b.ColumnID = c.ColumnID)
				order by c.ColumnID;
			open c;
			fetch next from c into @EventName, @Definition;
			while @@fetch_status = 0
			begin
				if not exists(select 1 from sys.columns where object_id = object_id(@ReceivingTable) and name = @EventName)
				begin
					select @SQL = N'alter table ' + quotename(parsename(@ReceivingTable, 2)) + N'.' + quotename(parsename(@ReceivingTable, 1)) + N' add ' + quotename(@EventName) + N' ' + @Definition + N' null;';
					exec sys.sp_executesql @SQL;
				end;
				fetch next from c into @EventName, @Definition;
			end;
			close c;
			deallocate c;
			commit;
			fetch next from d into @ReceivingTable;
		end;
		close d;
		deallocate d;
		select @Declarations = (select N', @C' + convert(nvarchar(10), ColumnID) + N' ' + Definition from #Columns order by ColumnID for xml path(''), type).value('.', 'nvarchar(max)'),
			@Reset = (select N', @C' + convert(nvarchar(10), ColumnID) + N' = null' from #Columns order by ColumnID for xml path(''), type).value('.', 'nvarchar(max)');
		select @Decode =
		(
			select N'
				' + case when row_number() over(order by ColumnID) = 1 then N'if' else N'else if' end + N' @ColumnID = ' + convert(nvarchar(10), ColumnID) + N'
					select @C' + convert(nvarchar(10), ColumnID) + N' = ' +
				case DataType
					when 'bigint' then N'convert(bigint, convert(binary(8), reverse(substring(@Data, 1, 8))))'
					when 'int' then N'convert(int, convert(binary(4), reverse(substring(@Data, 1, 4))))'
					when 'datetime' then N'datetimefromparts(Y, M, D, HH, MM, SS, MS)
					from (select convert(int, convert(binary(2), reverse(substring(@Data, 1, 2)))) Y, convert(int, convert(binary(2), reverse(substring(@Data, 3, 2)))) M,
						convert(int, convert(binary(2), reverse(substring(@Data, 7, 2)))) D, convert(int, convert(binary(2), reverse(substring(@Data, 9, 2)))) HH,
						convert(int, convert(binary(2), reverse(substring(@Data, 11, 2)))) MM, convert(int, convert(binary(2), reverse(substring(@Data, 13, 2)))) SS,
						convert(int, convert(binary(2), reverse(substring(@Data, 15, 2)))) MS) d'
					else N'convert(' + Definition + N', @Data)'
				end + N';'
			from #Columns order by ColumnID for xml path(''), type
		).value('.', 'nvarchar(max)');
		declare r cursor local static read_only for select TraceID, ReceivingTable from #Traces order by TraceID;
		open r;
		fetch next from r into @TraceID, @ReceivingTable;
		while @@fetch_status = 0
		begin
			select @ColumnNames = (select N', ' + quotename(c.ColumnName) from #Columns c
				where exists(select 1 from #SelectedColumns b where b.TraceID = @TraceID and b.ColumnID = c.ColumnID)
				order by c.ColumnID for xml path(''), type).value('.', 'nvarchar(max)'),
				@Values = (select N', case when @EventID in ('
					+ (select string_agg(convert(nvarchar(max), EventID), N',') within group(order by EventID)
						from #SelectedColumns b where b.TraceID = @TraceID and b.ColumnID = c.ColumnID)
					+ N') then @C' + convert(nvarchar(10), c.ColumnID) + N' end' from #Columns c
					where exists(select 1 from #SelectedColumns b where b.TraceID = @TraceID and b.ColumnID = c.ColumnID)
					order by c.ColumnID for xml path(''), type).value('.', 'nvarchar(max)');
			select @Routes += N'
				if @CurrentTraceID = ' + convert(nvarchar(10), @TraceID) + N'
				begin
					select @Operation = N''insert'';
					insert ' + quotename(parsename(@ReceivingTable, 2)) + N'.' + quotename(parsename(@ReceivingTable, 1))
					+ N' (TraceSequence, EventID, EventName' + @ColumnNames + N')
						values (@TraceSequence, @EventID, @EventName' + @Values + N');';
			declare g cursor local static read_only for
				select EventName, quotename(parsename(ProcedureName, 2)) + N'.' + quotename(parsename(ProcedureName, 1))
				from #Callbacks where TraceID = @TraceID
					and (EventName = N'all' or not exists(select 1 from #Callbacks where TraceID = @TraceID and EventName = N'all'))
				order by EventName;
			open g;
			fetch next from g into @EventName, @Callback;
			while @@fetch_status = 0
			begin
				select @Routes += N'
					' + case when @EventName = N'all' then N'' else N'if @EventName = N' + quotename(@EventName, '''') + N' ' end + N'
					begin
						select @Operation = N''callback ' + replace(@Callback, '''', '''''') + N''';
						exec ' + @Callback + N' @TraceSequence = @TraceSequence, @TraceID = @CurrentTraceID, @EventName = @EventName;
					end;';
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
		select @SQL = N'declare @EventID int, @EventName nvarchar(128), @ColumnID int, @Data varbinary(max), @TraceSequence bigint,
	@BatchCount int = 0, @BatchStarted datetime2(7), @ReadEvents int, @FetchStatus int, @FrameLength int,
	@CurrentTraceID int, @CurrentName nvarchar(128), @Operation nvarchar(600),
	@StartedUTC datetime2(7) = sysutcdatetime(), @Diagnostic nvarchar(2048)' + @Declarations + N';
create table #Buffer (Ordinal bigint identity(1,1) not null, ColumnID int, FrameLength int, Data varbinary(max));
create unique clustered index IX_Buffer on #Buffer(Ordinal);
begin try
	while datediff_big(second, @StartedUTC, sysutcdatetime()) < @MaxDurationInSec
	begin
		select @ReadEvents = 0;
		-- A selected trace stopped elsewhere leaves polling normally.
		delete s from #Traces s where not exists
			(select 1 from z.Trace t inner join sys.traces n on n.id = t.TraceID
				and n.stop_time is null and n.is_rowset = 1 and n.status = 1
			 where t.TraceID = s.TraceID
				and t.CreatorSessionID = @@spid and t.CreatorLoginTime = s.CreatorLoginTime);
		if not exists(select 1 from #Traces) break;
		declare cTrace cursor local static read_only for select TraceID, Name from #Traces order by TraceID;
		open cTrace;
		fetch next from cTrace into @CurrentTraceID, @CurrentName;
		while @@fetch_status = 0
		begin
			if datediff_big(second, @StartedUTC, sysutcdatetime()) >= @MaxDurationInSec break;
			if @@trancount > 0 and datediff_big(millisecond, @BatchStarted, sysutcdatetime()) >= convert(bigint, @TransactionDurationInSec) * 1000
			begin
				commit;
				select @BatchCount = 0, @BatchStarted = null;
			end;
			select @Operation = N''read'';
			truncate table #Buffer;
			begin try
				if exists(select 1 from sys.traces where id = @CurrentTraceID and stop_time is null and is_rowset = 1 and status = 1)
					insert #Buffer (ColumnID, FrameLength, Data) exec sys.sp_trace_getdata @CurrentTraceID, 1;
			end try
			begin catch
				-- Only trace-not-found is a normal concurrent Close; preserve every other native error.
				if error_number() <> 19059 throw;
				if xact_state() = -1 throw;
				if exists(select 1 from sys.traces where id = @CurrentTraceID and stop_time is null and is_rowset = 1 and status = 1) throw;
				truncate table #Buffer;
			end catch;
			select @Operation = N''decode'', @EventID = null, @EventName = null;
			declare cTraceBuffer cursor local static read_only for select ColumnID, FrameLength, Data from #Buffer order by Ordinal;
			open cTraceBuffer;
			fetch next from cTraceBuffer into @ColumnID, @FrameLength, @Data;
			select @FetchStatus = @@fetch_status;
			while @FetchStatus = 0
			begin
				select @Operation = N''decode'';
				if @ColumnID = 65526
				begin
					select @EventID = convert(int, convert(binary(2), reverse(substring(@Data, 1, 2)))), @EventName = null' + @Reset + N';
					select @EventName = case @EventID' + (select N' when ' + convert(nvarchar(10), TraceEventID) + N' then N' + quotename(EventName, '''') from z.v_TraceEvent order by TraceEventID for xml path(''), type).value('.', 'nvarchar(max)') + N' end;
				end
				else if @EventName is not null
				begin' + @Decode + N'
				end;
				fetch next from cTraceBuffer into @ColumnID, @FrameLength, @Data;
				-- Callbacks can use cursors: save this cursor status before invoking them.
				select @FetchStatus = @@fetch_status;
				if @EventName is not null and (@FetchStatus <> 0 or @ColumnID = 65526)
				begin
					if @@trancount = 0
					begin
						begin tran;
						select @BatchStarted = sysutcdatetime(), @BatchCount = 0;
					end;
					select @C27 = @EventID, @ReadEvents += 1,
						@TraceSequence = datediff_big(second, ''1900-01-01'', getutcdate()) * 268435456 | next value for z.SeqGeneralID;
' + @Routes + N'
					select @BatchCount += 1;
					if (@MaxEventsPerTransaction is not null and @BatchCount >= @MaxEventsPerTransaction)
						or datediff_big(millisecond, @BatchStarted, sysutcdatetime()) >= convert(bigint, @TransactionDurationInSec) * 1000
					begin
						commit;
						select @BatchCount = 0, @BatchStarted = null;
					end;
				end;
			end;
			close cTraceBuffer;
			deallocate cTraceBuffer;
			fetch next from cTrace into @CurrentTraceID, @CurrentName;
		end;
		close cTrace;
		deallocate cTrace;
		-- Expire pending work even when native reads return no events.
		if @@trancount > 0 and datediff_big(millisecond, @BatchStarted, sysutcdatetime()) >= convert(bigint, @TransactionDurationInSec) * 1000
		begin
			commit;
			select @BatchCount = 0, @BatchStarted = null;
		end;
		if @ReadEvents = 0 waitfor delay ''00:00:00.004'';
	end;
	-- Normal duration expiry or external Stop flushes a partial batch.
	if @@trancount > 0 commit;
end try
begin catch
	if @@trancount > 0 rollback;
	select @Diagnostic = N''Trace '' + convert(nvarchar(10), @CurrentTraceID) + N'' ('' + isnull(@CurrentName, N'''') + N'') failed during '' + isnull(@Operation, N''collection'') + N''.'';
	print @Diagnostic;
	throw;
end catch;';
		exec sys.sp_executesql @SQL, N'@MaxDurationInSec int, @TransactionDurationInSec int, @MaxEventsPerTransaction int',
			@MaxDurationInSec, @TransactionDurationInSec, @MaxEventsPerTransaction;
	end try
	begin catch
		if @@trancount > 0 rollback;
		declare e cursor local static read_only for
			select s.TraceID, s.CreatorLoginTime from #CleanupTraces s inner join z.Trace t on t.TraceID = s.TraceID
				and t.CreatorSessionID = @@spid and t.CreatorLoginTime = s.CreatorLoginTime;
		open e;
		fetch next from e into @TraceID, @CleanupLoginTime;
		while @@fetch_status = 0
		begin
			begin try
				exec z.usp_TraceClose @TraceID = @TraceID, @ExpectedCreatorSessionID = @@spid,
					@ExpectedCreatorLoginTime = @CleanupLoginTime;
			end try
			begin catch
				print N'Trace error cleanup failed; run z.usp_TraceCleanup after the owner disconnects.';
			end catch;
			fetch next from e into @TraceID, @CleanupLoginTime;
		end;
		close e;
		deallocate e;
		throw;
	end catch;
	declare x cursor local static read_only for
		select s.TraceID, s.CreatorLoginTime from #CleanupTraces s inner join z.Trace t on t.TraceID = s.TraceID
			and t.CreatorSessionID = @@spid and t.CreatorLoginTime = s.CreatorLoginTime;
	open x;
	fetch next from x into @TraceID, @CleanupLoginTime;
	while @@fetch_status = 0
	begin
		begin try
			exec z.usp_TraceClose @TraceID = @TraceID, @ExpectedCreatorSessionID = @@spid,
				@ExpectedCreatorLoginTime = @CleanupLoginTime;
		end try
		begin catch
			-- Attempt every remaining selected trace, then rethrow this first close error.
			fetch next from x into @TraceID, @CleanupLoginTime;
			while @@fetch_status = 0
			begin
				begin try
					exec z.usp_TraceClose @TraceID = @TraceID, @ExpectedCreatorSessionID = @@spid,
						@ExpectedCreatorLoginTime = @CleanupLoginTime;
				end try
				begin catch
					print N'Additional trace cleanup failed; run z.usp_TraceCleanup after the owner disconnects.';
				end catch;
				fetch next from x into @TraceID, @CleanupLoginTime;
			end;
			close x;
			deallocate x;
			throw;
		end catch;
		fetch next from x into @TraceID, @CleanupLoginTime;
	end;
	close x;
	deallocate x;
end;
go
