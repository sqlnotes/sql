/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/010-Trace/modules/1070%20Procedures/z.usp_TraceCleanup.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/010-Trace/docs/reference/z.usp_TraceCleanup.md

Closes registered native traces only after their creating sessions have ended.
*/
create or alter procedure z.usp_TraceCleanup
as
begin
	set nocount, xact_abort on;
	if @@trancount > 0
	begin
		set xact_abort off;
		throw 50000, N'Trace cleanup requires no existing transaction.', 1;
	end;
	declare @Permission sysname = case when convert(int, serverproperty('ProductMajorVersion')) >= 16
		then N'VIEW SERVER PERFORMANCE STATE' else N'VIEW SERVER STATE' end;
	if isnull(has_perms_by_name(null, null, @Permission), 0) <> 1
		throw 50000, N'Trace cleanup requires full server session visibility.', 1;
	declare @TraceID int, @CreatorSessionID int, @CreatorLoginTime datetime,
		@ReturnCode int, @Message nvarchar(2048);
	declare t cursor local static read_only for
		select TraceID, CreatorSessionID, CreatorLoginTime from z.Trace r
		where not exists(select 1 from sys.dm_exec_sessions s where s.session_id = r.CreatorSessionID and s.login_time = r.CreatorLoginTime);
	open t;
	fetch next from t into @TraceID, @CreatorSessionID, @CreatorLoginTime;
	while @@fetch_status = 0
	begin
		-- Lock the exact registration until its native resource and metadata are retired.
		-- An idle but connected session retains its traces; no active-request test is used.
		begin try
			begin tran;
			if exists(select 1 from z.Trace with (updlock, holdlock) where TraceID = @TraceID
				and CreatorSessionID = @CreatorSessionID and CreatorLoginTime = @CreatorLoginTime)
				and not exists(select 1 from sys.dm_exec_sessions where session_id = @CreatorSessionID and login_time = @CreatorLoginTime)
			begin
				if exists(select 1 from sys.traces where id = @TraceID and is_rowset = 1 and stop_time is null and status = 1)
				begin
					begin try
						exec @ReturnCode = sys.sp_trace_setstatus @TraceID, 0;
						if @ReturnCode <> 0 and exists(select 1 from sys.traces where id = @TraceID and is_rowset = 1 and stop_time is null and status = 1)
						begin
							select @Message = concat(N'Abandoned native trace ', @TraceID, N': stop failed; return code ', @ReturnCode, N'.');
							throw 50000, @Message, 1;
						end;
					end try
					begin catch
						if exists(select 1 from sys.traces where id = @TraceID and is_rowset = 1 and stop_time is null and status = 1) throw;
					end catch;
				end;
				if exists(select 1 from sys.traces where id = @TraceID and is_rowset = 1 and stop_time is null)
				begin
					begin try
						exec @ReturnCode = sys.sp_trace_setstatus @TraceID, 2;
						if @ReturnCode <> 0 and exists(select 1 from sys.traces where id = @TraceID and is_rowset = 1 and stop_time is null)
						begin
							select @Message = concat(N'Abandoned native trace ', @TraceID, N': close failed; return code ', @ReturnCode, N'.');
							throw 50000, @Message, 1;
						end;
					end try
					begin catch
						if exists(select 1 from sys.traces where id = @TraceID and is_rowset = 1 and stop_time is null) throw;
					end catch;
				end;
				if not exists(select 1 from sys.traces where id = @TraceID and is_rowset = 1 and stop_time is null)
				begin
					delete z.TraceEventColumn where TraceID = @TraceID;
					delete z.TraceEvent where TraceID = @TraceID;
					delete z.TraceFilter where TraceID = @TraceID;
					delete z.TraceTrigger where TraceID = @TraceID;
					delete z.Trace where TraceID = @TraceID;
				end;
			end;
			commit;
		end try
		begin catch
			if @@trancount > 0 rollback;
			throw;
		end catch;
		fetch next from t into @TraceID, @CreatorSessionID, @CreatorLoginTime;
	end;
	close t;
	deallocate t;
end;
go
