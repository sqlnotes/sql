create or alter procedure z.usp_TraceClose
(
	@TraceName nvarchar(128) = null,
	@TraceID int = null
)
as
begin
	set nocount, xact_abort on;
	if @@trancount > 0
	begin
		set xact_abort off;
		throw 50000, N'Trace close requires no existing transaction.', 1;
	end;
	exec z.usp_TraceAssertOwner @TraceName, @TraceID;
	declare @CollectorUUID uniqueidentifier = try_convert(uniqueidentifier, session_context(N'Schema z.TraceCollector.UUID')),
		@State varchar(10), @NativeTraceID int, @NativeStartTime datetime, @NativeStopTime datetime, @ReturnCode int;
	select @State = State from z.TraceCollector where CollectorUUID = @CollectorUUID;
	if @State = 'Collecting' and (@TraceName is not null or @TraceID is not null)
		throw 50000, N'Close the whole collector run after collection starts; individual logical traces are frozen.', 1;
	select @NativeTraceID = TraceID, @NativeStartTime = NativeStartTime, @NativeStopTime = NativeStopTime
	from z.TraceCollectorTrace where CollectorUUID = @CollectorUUID;
	if @NativeTraceID is not null
	begin
		if exists(select 1 from sys.traces where id = @NativeTraceID
			and (stop_time <> @NativeStopTime or stop_time is null or (@NativeStartTime is not null and (start_time <> @NativeStartTime or start_time is null))))
			throw 50000, N'The native trace ID belongs to another generation; ownership is retained for manual review.', 1;
		if exists(select 1 from sys.traces where id = @NativeTraceID and stop_time = @NativeStopTime
			and (@NativeStartTime is null or start_time = @NativeStartTime) and status = 1)
		begin
			exec @ReturnCode = sys.sp_trace_setstatus @NativeTraceID, 0;
			if @ReturnCode <> 0 throw 50000, N'Failed to stop the owned physical trace.', 1;
		end;
		if exists(select 1 from sys.traces where id = @NativeTraceID and stop_time = @NativeStopTime
			and (@NativeStartTime is null or start_time = @NativeStartTime))
		begin
			exec @ReturnCode = sys.sp_trace_setstatus @NativeTraceID, 2;
			if @ReturnCode <> 0 throw 50000, N'Failed to close the owned physical trace.', 1;
		end;
		if exists(select 1 from sys.traces where id = @NativeTraceID)
			throw 50000, N'Native trace ownership could not be released safely.', 1;
	end;
	begin try
		begin tran;
		delete c from z.TraceEventColumn c inner join z.Trace t on t.TraceID = c.TraceID
		where t.CollectorUUID = @CollectorUUID and (@TraceName is null or t.Name = @TraceName) and (@TraceID is null or t.TraceID = @TraceID);
		delete e from z.TraceEvent e inner join z.Trace t on t.TraceID = e.TraceID
		where t.CollectorUUID = @CollectorUUID and (@TraceName is null or t.Name = @TraceName) and (@TraceID is null or t.TraceID = @TraceID);
		delete f from z.TraceFilter f inner join z.Trace t on t.TraceID = f.TraceID
		where t.CollectorUUID = @CollectorUUID and (@TraceName is null or t.Name = @TraceName) and (@TraceID is null or t.TraceID = @TraceID);
		delete g from z.TraceTrigger g inner join z.Trace t on t.TraceID = g.TraceID
		where t.CollectorUUID = @CollectorUUID and (@TraceName is null or t.Name = @TraceName) and (@TraceID is null or t.TraceID = @TraceID);
		delete z.Trace where CollectorUUID = @CollectorUUID and (@TraceName is null or Name = @TraceName) and (@TraceID is null or TraceID = @TraceID);
		if @NativeTraceID is not null delete z.TraceCollectorTrace where CollectorUUID = @CollectorUUID;
		commit;
	end try
	begin catch
		if @@trancount > 0 rollback;
		throw;
	end catch;
	exec z.usp_TraceReleaseCollector;
end;
go
