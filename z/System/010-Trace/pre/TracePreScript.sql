-- Installation closes the previous shared collector before replacing its schema.
-- Native effects cannot be rolled back; preserve registrations on failure for retry.
if @@trancount > 0 throw 50000, N'Trace installation requires no existing transaction.', 1;
declare @LegacyTrace bit = iif(col_length(N'z.Trace', N'CollectorUUID') is not null
	or columnproperty(object_id(N'z.Trace'), N'TraceID', 'IsIdentity') = 1, 1, 0),
	@SQL nvarchar(max), @LockResult int, @Rows bigint;
if @LegacyTrace = 1 or object_id(N'z.TraceCollectorTrace', N'U') is not null or object_id(N'z.TraceCollector', N'U') is not null
begin
	begin try
		begin tran;
		exec @LockResult = z.usp_AcquireSemaphore @SemaphoreName = N'Schema z.TraceCollector', @TotalCount = 1, @LockOwner = N'Transaction', @LockTimeout = 5000;
		if @LockResult <= 0 throw 50000, N'Trace collector admission or cleanup is already in progress.', 1;
		if object_id(N'z.TraceCollector', N'U') is not null
			exec sys.sp_executesql N'select @Rows = count_big(*) from z.TraceCollector with (tablockx, holdlock);', N'@Rows bigint output', @Rows output;
		if @LegacyTrace = 1
			select @Rows = count_big(*) from z.Trace with (tablockx, holdlock);
		if object_id(N'z.TraceCollectorTrace', N'U') is not null
		begin
			select @SQL = N'
declare @TraceID int, @Started datetime, @Stopped datetime, @ReturnCode int;
declare n cursor local static read_only for
	select TraceID, ' + iif(col_length(N'z.TraceCollectorTrace', N'NativeStartTime') is null, N'convert(datetime, null)', N'NativeStartTime') + N', NativeStopTime
	from z.TraceCollectorTrace with (tablockx, holdlock);
open n;
fetch next from n into @TraceID, @Started, @Stopped;
while @@fetch_status = 0
begin
	if exists(select 1 from sys.traces where id = @TraceID and is_default = 0 and is_rowset = 1
		and stop_time = @Stopped and (@Started is null or start_time = @Started))
	begin
		if exists(select 1 from sys.traces where id = @TraceID and status = 1 and is_default = 0 and is_rowset = 1
			and stop_time = @Stopped and (@Started is null or start_time = @Started))
		begin
			begin try
				exec @ReturnCode = sys.sp_trace_setstatus @TraceID, 0;
				if @ReturnCode <> 0 and exists(select 1 from sys.traces where id = @TraceID and status = 1 and is_default = 0 and is_rowset = 1
					and stop_time = @Stopped and (@Started is null or start_time = @Started))
					throw 50000, N''Failed to stop a previous trace generation during installation.'', 1;
			end try
			begin catch
				if xact_state() = -1 or exists(select 1 from sys.traces where id = @TraceID and status = 1 and is_default = 0 and is_rowset = 1
					and stop_time = @Stopped and (@Started is null or start_time = @Started)) throw;
			end catch;
		end;
		if exists(select 1 from sys.traces where id = @TraceID and is_default = 0 and is_rowset = 1
			and stop_time = @Stopped and (@Started is null or start_time = @Started))
		begin
			begin try
				exec @ReturnCode = sys.sp_trace_setstatus @TraceID, 2;
				if @ReturnCode <> 0 and exists(select 1 from sys.traces where id = @TraceID and is_default = 0 and is_rowset = 1
					and stop_time = @Stopped and (@Started is null or start_time = @Started))
					throw 50000, N''Failed to close a previous trace generation during installation.'', 1;
			end try
			begin catch
				if xact_state() = -1 or exists(select 1 from sys.traces where id = @TraceID and is_default = 0 and is_rowset = 1
					and stop_time = @Stopped and (@Started is null or start_time = @Started)) throw;
			end catch;
		end;
		if exists(select 1 from sys.traces where id = @TraceID and is_default = 0 and is_rowset = 1
			and stop_time = @Stopped and (@Started is null or start_time = @Started))
			throw 50000, N''A previous trace generation remains open after installation cleanup.'', 1;
	end;
	fetch next from n into @TraceID, @Started, @Stopped;
end;
close n;
deallocate n;
delete z.TraceCollectorTrace;';
			exec sys.sp_executesql @SQL;
		end;
		if @LegacyTrace = 1
		begin
			delete z.TraceEventColumn;
			delete z.TraceEvent;
			delete z.TraceFilter;
			delete z.TraceTrigger;
			delete z.Trace;
		end;
		if object_id(N'z.TraceCollector', N'U') is not null
			exec sys.sp_executesql N'delete z.TraceCollector;';
		commit;
	end try
	begin catch
		if @@trancount > 0 rollback;
		throw;
	end catch;
end;
go
