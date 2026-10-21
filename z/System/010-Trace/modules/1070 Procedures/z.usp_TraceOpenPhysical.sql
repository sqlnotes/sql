create or alter procedure z.usp_TraceOpenPhysical
(
	@NativeTraceID int output
)
as
begin
	set nocount, xact_abort on;
	if @@trancount > 0
	begin
		set xact_abort off;
		throw 50000, N'Physical trace creation requires no existing transaction.', 1;
	end;
	exec z.usp_TraceAssertOwner;
	declare @CollectorUUID uniqueidentifier = try_convert(uniqueidentifier, session_context(N'Schema z.TraceCollector.UUID')),
		@NativeStopTime datetime, @TraceFile nvarchar(256) = null, @MaxFileSize bigint = 5,
		@ReturnCode int, @EventID int, @ColumnID int, @SPIDValue int, @ComparisonOperator varchar(8), @ComparisonInt int;
	select @NativeTraceID = null;
	if not exists(select 1 from z.TraceCollector where CollectorUUID = @CollectorUUID and State = 'Building')
		throw 50000, N'The current collector is already collecting.', 1;
	if not exists(select 1 from z.Trace where CollectorUUID = @CollectorUUID and IsEnabled = 1)
		throw 50000, N'Enable at least one logical trace before collecting.', 1;
	if exists
	(
		select 1 from z.Trace t where t.CollectorUUID = @CollectorUUID and t.IsEnabled = 1
			and not exists(select 1 from z.TraceEvent e where e.TraceID = t.TraceID)
	)
		throw 50000, N'Every enabled logical trace must select at least one event.', 1;
	-- Freeze the run before any nontransactional native allocation.
	update z.TraceCollector set State = 'Collecting' where CollectorUUID = @CollectorUUID and State = 'Building';
	if @@rowcount <> 1 throw 50000, N'The collector state changed before native allocation.', 1;
	begin try
		-- Expiry distinguishes a recycled native ID even before the first start.
		select @NativeStopTime = dateadd(millisecond, convert(int, abs(convert(bigint, checksum(newid()))) % 86400000),
			dateadd(day, convert(int, abs(convert(bigint, checksum(newid()))) % 36500), convert(datetime, '22000101')));
		exec @ReturnCode = sys.sp_trace_create @traceid = @NativeTraceID output, @options = 1, @tracefile = @TraceFile,
			@maxfilesize = @MaxFileSize, @stoptime = @NativeStopTime;
		if @ReturnCode <> 0 throw 50000, N'Failed to allocate the physical trace.', 1;
		-- Register ownership immediately; native allocation is not rolled back by SQL transactions.
		insert z.TraceCollectorTrace (CollectorUUID, TraceID, NativeStartTime, NativeStopTime, TraceName)
			select @CollectorUUID, @NativeTraceID, start_time, stop_time, convert(nvarchar(128), @CollectorUUID)
			from sys.traces where id = @NativeTraceID and stop_time = @NativeStopTime;
		if @@rowcount <> 1 throw 50000, N'Physical trace ownership could not be registered.', 1;
		declare e cursor local static for
			select distinct e.EventID, b.trace_column_id
			from z.Trace t
				inner join z.TraceEvent e on e.TraceID = t.TraceID
				inner join sys.trace_event_bindings b on b.trace_event_id = e.EventID
			where t.CollectorUUID = @CollectorUUID and t.IsEnabled = 1
				and (b.trace_column_id = 12
					or exists(select 1 from z.TraceEventColumn c where c.TraceID = t.TraceID and c.EventID = e.EventID and c.ColumnID = b.trace_column_id)
					or exists(select 1 from z.TraceFilter f where f.TraceID = t.TraceID and f.ColumnID = b.trace_column_id))
			order by e.EventID, b.trace_column_id;
		open e;
		fetch next from e into @EventID, @ColumnID;
		while @@fetch_status = 0
		begin
			exec @ReturnCode = sys.sp_trace_setevent @NativeTraceID, @EventID, @ColumnID, 1;
			if @ReturnCode <> 0 throw 50000, N'Failed to configure a physical trace event-column binding.', 1;
			fetch next from e into @EventID, @ColumnID;
		end;
		close e;
		deallocate e;
		-- Only an identical, single SPID predicate in every enabled definition is pushed down.
		-- All independent logical predicates remain in the receiver's local routing expression.
		select top (1) @SPIDValue = try_convert(int, f.Value), @ComparisonOperator = f.ComparisonOperator
		from z.Trace t inner join z.TraceFilter f on f.TraceID = t.TraceID
		where t.CollectorUUID = @CollectorUUID and t.IsEnabled = 1 and f.ColumnID = 12 and f.ComparisonOperator in ('=', '<>', '!=');
		if @SPIDValue is not null and not exists
		(
			select 1 from z.Trace t where t.CollectorUUID = @CollectorUUID and t.IsEnabled = 1
				and ((select count(*) from z.TraceFilter f where f.TraceID = t.TraceID and f.ColumnID = 12) <> 1
					or not exists(select 1 from z.TraceFilter f where f.TraceID = t.TraceID and f.ColumnID = 12
						and f.ComparisonOperator = @ComparisonOperator and try_convert(int, f.Value) = @SPIDValue))
		)
		begin
			select @ComparisonInt = case when @ComparisonOperator = '=' then 0 else 1 end;
			exec @ReturnCode = sys.sp_trace_setfilter @NativeTraceID, 12, 0, @ComparisonInt, @SPIDValue;
			if @ReturnCode <> 0 throw 50000, N'Failed to configure the shared SPID predicate.', 1;
		end;
		exec @ReturnCode = sys.sp_trace_setstatus @NativeTraceID, 1;
		if @ReturnCode <> 0 throw 50000, N'Failed to start the physical trace.', 1;
		update m set NativeStartTime = n.start_time
		from z.TraceCollectorTrace m inner join sys.traces n on n.id = m.TraceID and n.stop_time = m.NativeStopTime
		where m.CollectorUUID = @CollectorUUID;
		if @@rowcount <> 1 throw 50000, N'Physical trace start ownership could not be recorded.', 1;
	end try
	begin catch
		-- Cover registration failures before a mapping exists without touching an ID's other generation.
		begin try
			if @NativeTraceID is not null and not exists(select 1 from z.TraceCollectorTrace where CollectorUUID = @CollectorUUID)
				and exists(select 1 from sys.traces where id = @NativeTraceID and stop_time = @NativeStopTime)
			begin
				exec @ReturnCode = sys.sp_trace_setstatus @NativeTraceID, 2;
				if @ReturnCode <> 0 throw 50000, N'Unregistered physical trace cleanup failed; manual review is required.', 1;
			end;
			exec z.usp_TraceClose;
		end try
		begin catch
			print N'Physical trace setup cleanup failed; retained ownership or the native allocation requires review.';
		end catch;
		throw;
	end catch;
end;
go
