create or alter procedure z.usp_TraceStop
(
	@TraceName nvarchar(128) = null,
	@TraceID int = null
)
as
begin
	set nocount, xact_abort on;
	declare @CurrentCollectorUUID uniqueidentifier = try_convert(uniqueidentifier, session_context(N'Schema z.TraceCollector.UUID')),
		@CollectorUUID uniqueidentifier, @NativeTraceID int, @NativeStartTime datetime, @NativeStopTime datetime, @ReturnCode int,
		@Failed bit = 0, @Message nvarchar(2048);
	declare @Targets table (TraceID int not null primary key, CollectorUUID uniqueidentifier not null);
	declare @Runs table (CollectorUUID uniqueidentifier not null primary key);
	insert @Targets (TraceID, CollectorUUID)
		select TraceID, CollectorUUID from z.Trace
		where (@TraceName is not null or @TraceID is not null or CollectorUUID = @CurrentCollectorUUID)
			and (@TraceName is null or Name = @TraceName) and (@TraceID is null or TraceID = @TraceID);
	insert @Runs (CollectorUUID) select distinct CollectorUUID from @Targets;
	if @TraceName is null and @TraceID is null and @CurrentCollectorUUID is not null
		and not exists(select 1 from @Runs where CollectorUUID = @CurrentCollectorUUID)
		insert @Runs (CollectorUUID) values (@CurrentCollectorUUID);
	update t set IsEnabled = 0, ModificationDate = getdate() from z.Trace t inner join @Targets s on s.TraceID = t.TraceID;
	-- Other enabled definitions retain their shared physical generations.
	declare n cursor local static read_only for
		select m.CollectorUUID, m.TraceID, m.NativeStartTime, m.NativeStopTime
		from z.TraceCollectorTrace m inner join @Runs r on r.CollectorUUID = m.CollectorUUID
		where not exists(select 1 from z.Trace t where t.CollectorUUID = m.CollectorUUID and t.IsEnabled = 1)
		order by m.CollectorUUID, m.NativeStopTime, m.TraceID;
	open n;
	fetch next from n into @CollectorUUID, @NativeTraceID, @NativeStartTime, @NativeStopTime;
	while @@fetch_status = 0
	begin
		begin try
			if not exists(select 1 from z.Trace where CollectorUUID = @CollectorUUID and IsEnabled = 1)
				and exists(select 1 from sys.traces where id = @NativeTraceID and stop_time = @NativeStopTime
					and (@NativeStartTime is null or start_time = @NativeStartTime) and status = 1)
			begin
				exec @ReturnCode = sys.sp_trace_setstatus @NativeTraceID, 0;
				if @ReturnCode <> 0 throw 50000, N'Failed to stop a physical generation for the selected logical traces.', 1;
			end;
		end try
		begin catch
			-- A concurrent caller may already have stopped or removed this generation.
			if exists(select 1 from sys.traces where id = @NativeTraceID and stop_time = @NativeStopTime
				and (@NativeStartTime is null or start_time = @NativeStartTime) and status = 1)
				select @Failed = 1, @Message = isnull(@Message, error_message());
		end catch;
		fetch next from n into @CollectorUUID, @NativeTraceID, @NativeStartTime, @NativeStopTime;
	end;
	close n;
	deallocate n;
	if @Failed = 1 throw 50000, @Message, 1;
end;
go
