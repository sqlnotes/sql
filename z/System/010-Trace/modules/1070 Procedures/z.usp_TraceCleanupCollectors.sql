create or alter procedure z.usp_TraceCleanupCollectors
as
begin
	set nocount on;
	if @@trancount > 0
	begin
		set xact_abort off;
		throw 50000, N'Trace collector cleanup requires no existing transaction.', 1;
	end;
	set xact_abort on;
	declare @Permission sysname = case when convert(int, serverproperty('ProductMajorVersion')) >= 16
		then N'VIEW SERVER PERFORMANCE STATE' else N'VIEW SERVER STATE' end;
	if isnull(has_perms_by_name(null, null, @Permission), 0) <> 1
		throw 50000, N'Trace collector cleanup requires full server request/session visibility.', 1;
	declare @LockResult int, @CollectorUUID uniqueidentifier, @OwnerSessionID smallint, @OwnerLoginTime datetime, @State varchar(10),
		@NativeTraceID int, @NativeStartTime datetime, @NativeStopTime datetime, @ReturnCode int, @OwnerResumed bit;
	begin try
		begin tran;
		exec @LockResult = sys.sp_getapplock @Resource = N'Schema z.TraceCollector', @LockMode = N'Exclusive', @LockOwner = N'Transaction', @LockTimeout = 5000;
		if @LockResult < 0 throw 50000, N'Trace collector coordination lock could not be acquired.', 1;
		declare r cursor local static for select CollectorUUID, OwnerSessionID, OwnerLoginTime, State from z.TraceCollector;
		open r;
		fetch next from r into @CollectorUUID, @OwnerSessionID, @OwnerLoginTime, @State;
		while @@fetch_status = 0
		begin
			-- Idle Building runs are valid configuration; Collecting runs require an active owner request.
			if not exists(select 1 from sys.dm_exec_sessions s where s.session_id = @OwnerSessionID and s.login_time = @OwnerLoginTime
				and (@State = 'Building' or exists(select 1 from sys.dm_exec_requests q where q.session_id = s.session_id)))
			begin
				select @OwnerResumed = 0;
				declare n cursor local static read_only for
					select TraceID, NativeStartTime, NativeStopTime from z.TraceCollectorTrace
					where CollectorUUID = @CollectorUUID order by NativeStopTime, TraceID;
				open n;
				fetch next from n into @NativeTraceID, @NativeStartTime, @NativeStopTime;
				while @@fetch_status = 0
				begin
					if exists(select 1 from sys.dm_exec_sessions s where s.session_id = @OwnerSessionID and s.login_time = @OwnerLoginTime
						and (@State = 'Building' or exists(select 1 from sys.dm_exec_requests q where q.session_id = s.session_id)))
					begin
						select @OwnerResumed = 1;
						break;
					end;
					if exists(select 1 from sys.traces where id = @NativeTraceID and stop_time = @NativeStopTime
						and (@NativeStartTime is null or start_time = @NativeStartTime) and status = 1)
					begin
						exec @ReturnCode = sys.sp_trace_setstatus @NativeTraceID, 0;
						if @ReturnCode <> 0 throw 50000, N'Failed to stop an abandoned owned native trace.', 1;
					end;
					if exists(select 1 from sys.dm_exec_sessions s where s.session_id = @OwnerSessionID and s.login_time = @OwnerLoginTime
						and (@State = 'Building' or exists(select 1 from sys.dm_exec_requests q where q.session_id = s.session_id)))
					begin
						select @OwnerResumed = 1;
						break;
					end;
					if exists(select 1 from sys.traces where id = @NativeTraceID and stop_time = @NativeStopTime
						and (@NativeStartTime is null or start_time = @NativeStartTime))
					begin
						exec @ReturnCode = sys.sp_trace_setstatus @NativeTraceID, 2;
						if @ReturnCode <> 0 throw 50000, N'Failed to close an abandoned owned native trace.', 1;
					end;
					-- Preserve only unresolved mappings; other generations and owners can still be cleaned.
					if not exists(select 1 from sys.traces where id = @NativeTraceID)
						delete z.TraceCollectorTrace where CollectorUUID = @CollectorUUID and TraceID = @NativeTraceID and NativeStopTime = @NativeStopTime;
					fetch next from n into @NativeTraceID, @NativeStartTime, @NativeStopTime;
				end;
				close n;
				deallocate n;
				-- A reused ID remains registered for review and never blocks other owners' admission.
				if @OwnerResumed = 0 and not exists(select 1 from z.TraceCollectorTrace where CollectorUUID = @CollectorUUID)
					and not exists(select 1 from sys.dm_exec_sessions s where s.session_id = @OwnerSessionID and s.login_time = @OwnerLoginTime
						and (@State = 'Building' or exists(select 1 from sys.dm_exec_requests q where q.session_id = s.session_id)))
				begin
					delete d from z.TraceEventColumn d inner join z.Trace t on t.TraceID = d.TraceID where t.CollectorUUID = @CollectorUUID;
					delete d from z.TraceEvent d inner join z.Trace t on t.TraceID = d.TraceID where t.CollectorUUID = @CollectorUUID;
					delete d from z.TraceFilter d inner join z.Trace t on t.TraceID = d.TraceID where t.CollectorUUID = @CollectorUUID;
					delete d from z.TraceTrigger d inner join z.Trace t on t.TraceID = d.TraceID where t.CollectorUUID = @CollectorUUID;
					delete z.Trace where CollectorUUID = @CollectorUUID;
					delete z.TraceCollector where CollectorUUID = @CollectorUUID;
				end;
			end;
			fetch next from r into @CollectorUUID, @OwnerSessionID, @OwnerLoginTime, @State;
		end;
		close r;
		deallocate r;
		commit;
	end try
	begin catch
		if @@trancount > 0 rollback;
		throw;
	end catch;
end;
go
