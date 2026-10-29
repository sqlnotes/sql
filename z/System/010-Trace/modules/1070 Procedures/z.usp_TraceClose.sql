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
	declare @CurrentCollectorUUID uniqueidentifier = try_convert(uniqueidentifier, session_context(N'Schema z.TraceCollector.UUID')),
		@CollectorUUID uniqueidentifier, @NativeTraceID int, @NativeStartTime datetime, @NativeStopTime datetime, @ReturnCode int,
		@Unresolved bit = 0, @CleanupMessage nvarchar(2048), @LockResult int,
		@OwnerLoginTime datetime = (select login_time from sys.dm_exec_sessions where session_id = @@spid),
		@VisibilityPermission sysname = case when convert(int, serverproperty('ProductMajorVersion')) >= 16
			then N'VIEW SERVER PERFORMANCE STATE' else N'VIEW SERVER STATE' end,
		@CanSeeOwners bit;
	select @CanSeeOwners = isnull(has_perms_by_name(null, null, @VisibilityPermission), 0);
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
	if not exists(select 1 from @Runs) return;
	begin try
		begin tran;
		delete c from z.TraceEventColumn c inner join @Targets t on t.TraceID = c.TraceID;
		delete e from z.TraceEvent e inner join @Targets t on t.TraceID = e.TraceID;
		delete f from z.TraceFilter f inner join @Targets t on t.TraceID = f.TraceID;
		delete g from z.TraceTrigger g inner join @Targets t on t.TraceID = g.TraceID;
		delete t from z.Trace t inner join @Targets s on s.TraceID = t.TraceID;
		commit;
	end try
	begin catch
		if @@trancount > 0 rollback;
		throw;
	end catch;
	-- Selected definitions can be closed by another session; unrelated enabled definitions keep their pool.
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
			begin
				if exists(select 1 from sys.traces where id = @NativeTraceID and stop_time = @NativeStopTime
					and (@NativeStartTime is null or start_time = @NativeStartTime) and status = 1)
				begin
					begin try
						exec @ReturnCode = sys.sp_trace_setstatus @NativeTraceID, 0;
						if @ReturnCode <> 0 throw 50000, N'Failed to stop a selected physical generation.', 1;
					end try
					begin catch
						if exists(select 1 from sys.traces where id = @NativeTraceID and stop_time = @NativeStopTime
							and (@NativeStartTime is null or start_time = @NativeStartTime) and status = 1) throw;
					end catch;
				end;
				if exists(select 1 from sys.traces where id = @NativeTraceID and stop_time = @NativeStopTime
					and (@NativeStartTime is null or start_time = @NativeStartTime))
				begin
					exec @ReturnCode = sys.sp_trace_setstatus @NativeTraceID, 2;
					if @ReturnCode <> 0 throw 50000, N'Failed to close a selected physical generation.', 1;
				end;
				if not exists(select 1 from sys.traces where id = @NativeTraceID and stop_time = @NativeStopTime
					and (@NativeStartTime is null or start_time = @NativeStartTime))
					delete z.TraceCollectorTrace where CollectorUUID = @CollectorUUID and TraceID = @NativeTraceID and NativeStopTime = @NativeStopTime;
			end;
		end try
		begin catch
			-- Explicit close forgets a vanished generation even if its integer ID was recycled.
			if exists(select 1 from sys.traces where id = @NativeTraceID and stop_time = @NativeStopTime
				and (@NativeStartTime is null or start_time = @NativeStartTime))
				select @Unresolved = 1, @CleanupMessage = isnull(@CleanupMessage, error_message());
			else
				delete z.TraceCollectorTrace where CollectorUUID = @CollectorUUID and TraceID = @NativeTraceID and NativeStopTime = @NativeStopTime;
		end catch;
		fetch next from n into @CollectorUUID, @NativeTraceID, @NativeStartTime, @NativeStopTime;
	end;
	close n;
	deallocate n;
	begin try
		begin tran;
		exec @LockResult = sys.sp_getapplock @Resource = N'Schema z.TraceCollector', @LockMode = N'Exclusive', @LockOwner = N'Transaction', @LockTimeout = 5000;
		if @LockResult < 0 throw 50000, N'Trace collector admission or cleanup is already in progress.', 1;
		delete c from z.TraceCollector c inner join @Runs r on r.CollectorUUID = c.CollectorUUID
		where not exists(select 1 from z.Trace t where t.CollectorUUID = c.CollectorUUID)
			and not exists(select 1 from z.TraceCollectorTrace m where m.CollectorUUID = c.CollectorUUID)
			and c.OwnerSessionID = @@spid and c.OwnerLoginTime = @OwnerLoginTime;
		if @CanSeeOwners = 1
			delete c from z.TraceCollector c inner join @Runs r on r.CollectorUUID = c.CollectorUUID
			where not exists(select 1 from z.Trace t where t.CollectorUUID = c.CollectorUUID)
				and not exists(select 1 from z.TraceCollectorTrace m where m.CollectorUUID = c.CollectorUUID)
				and not exists(select 1 from sys.dm_exec_sessions s where s.session_id = c.OwnerSessionID and s.login_time = c.OwnerLoginTime
					and exists(select 1 from sys.dm_exec_requests q where q.session_id = s.session_id));
		commit;
	end try
	begin catch
		if @@trancount > 0 rollback;
		throw;
	end catch;
	if @CurrentCollectorUUID is not null and exists(select 1 from @Runs where CollectorUUID = @CurrentCollectorUUID)
		and not exists(select 1 from z.TraceCollector where CollectorUUID = @CurrentCollectorUUID)
		and not exists(select 1 from z.Trace where CollectorUUID = @CurrentCollectorUUID)
		and not exists(select 1 from z.TraceCollectorTrace where CollectorUUID = @CurrentCollectorUUID)
		exec sys.sp_set_session_context @key = N'Schema z.TraceCollector.UUID', @value = null;
	if @Unresolved = 1 throw 50000, @CleanupMessage, 1;
end;
go
