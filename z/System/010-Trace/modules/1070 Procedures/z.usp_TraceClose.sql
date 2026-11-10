/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/010-Trace/modules/1070%20Procedures/z.usp_TraceClose.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/010-Trace/docs/reference/z.usp_TraceClose.md

Stops and closes selected native traces and removes only their registrations.
*/
create or alter procedure z.usp_TraceClose
(
	@TraceName nvarchar(128) = null,
	@TraceID int = null,
	@ExpectedCreatorSessionID int = null,
	@ExpectedCreatorLoginTime datetime = null
)
as
begin
	set nocount, xact_abort on;
	if @@trancount > 0
	begin
		set xact_abort off;
		throw 50000, N'Trace close requires no existing transaction.', 1;
	end;
	if (@ExpectedCreatorSessionID is null and @ExpectedCreatorLoginTime is not null)
		or (@ExpectedCreatorSessionID is not null and @ExpectedCreatorLoginTime is null)
		throw 50000, N'Expected creator session ID and login time must be supplied together.', 1;
	declare @SelectedTraceID int, @CreatorSessionID int, @CreatorLoginTime datetime,
		@ReturnCode int, @Message nvarchar(2048), @CurrentLoginTime datetime = (select login_time from sys.dm_exec_sessions where session_id = @@spid);
	declare t cursor local static read_only for
		select TraceID, CreatorSessionID, CreatorLoginTime from z.Trace
		where (@TraceName is not null or @TraceID is not null or (CreatorSessionID = @@spid and CreatorLoginTime = @CurrentLoginTime))
			and (@TraceName is null or Name = @TraceName) and (@TraceID is null or TraceID = @TraceID)
			and (@ExpectedCreatorSessionID is null or (CreatorSessionID = @ExpectedCreatorSessionID and CreatorLoginTime = @ExpectedCreatorLoginTime));
	open t;
	fetch next from t into @SelectedTraceID, @CreatorSessionID, @CreatorLoginTime;
	while @@fetch_status = 0
	begin
		begin try
			begin tran;
			-- Hold this registration through native operations; never act on a replacement registration.
			if exists(select 1 from z.Trace with (updlock, holdlock) where TraceID = @SelectedTraceID
				and CreatorSessionID = @CreatorSessionID and CreatorLoginTime = @CreatorLoginTime)
			begin
				if exists(select 1 from sys.traces where id = @SelectedTraceID and is_rowset = 1 and stop_time is null and status = 1)
				begin
					begin try
						exec @ReturnCode = sys.sp_trace_setstatus @SelectedTraceID, 0;
						if @ReturnCode <> 0 and exists(select 1 from sys.traces where id = @SelectedTraceID and is_rowset = 1 and stop_time is null and status = 1)
						begin
							select @Message = concat(N'Native trace ', @SelectedTraceID, N': stop failed; return code ', @ReturnCode, N'.');
							throw 50000, @Message, 1;
						end;
					end try
					begin catch
						if exists(select 1 from sys.traces where id = @SelectedTraceID and is_rowset = 1 and stop_time is null and status = 1) throw;
					end catch;
				end;
				if exists(select 1 from sys.traces where id = @SelectedTraceID and is_rowset = 1 and stop_time is null)
				begin
					begin try
						exec @ReturnCode = sys.sp_trace_setstatus @SelectedTraceID, 2;
						if @ReturnCode <> 0 and exists(select 1 from sys.traces where id = @SelectedTraceID and is_rowset = 1 and stop_time is null)
						begin
							select @Message = concat(N'Native trace ', @SelectedTraceID, N': close failed; return code ', @ReturnCode, N'.');
							throw 50000, @Message, 1;
						end;
					end try
					begin catch
						if exists(select 1 from sys.traces where id = @SelectedTraceID and is_rowset = 1 and stop_time is null) throw;
					end catch;
				end;
				if not exists(select 1 from sys.traces where id = @SelectedTraceID and is_rowset = 1 and stop_time is null)
				begin
					delete z.TraceEventColumn where TraceID = @SelectedTraceID;
					delete z.TraceEvent where TraceID = @SelectedTraceID;
					delete z.TraceFilter where TraceID = @SelectedTraceID;
					delete z.TraceTrigger where TraceID = @SelectedTraceID;
					delete z.Trace where TraceID = @SelectedTraceID;
				end;
			end;
			commit;
		end try
		begin catch
			if @@trancount > 0 rollback;
			throw;
		end catch;
		fetch next from t into @SelectedTraceID, @CreatorSessionID, @CreatorLoginTime;
	end;
	close t;
	deallocate t;
end;
go
