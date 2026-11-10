/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/010-Trace/modules/1070%20Procedures/z.usp_TraceRemoveEvents.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/010-Trace/docs/reference/z.usp_TraceRemoveEvents.md

Removes selected native trace events and their columns and callbacks.
*/
create or alter procedure z.usp_TraceRemoveEvents
(
	@TraceName nvarchar(128) = null,
	@TraceID int = null,
	@EventList nvarchar(max) = null
)
as
begin
	set nocount, xact_abort on;
	if @@trancount > 0
	begin
		set xact_abort off;
		throw 50000, N'Trace configuration requires no existing transaction.', 1;
	end;
	begin try
		begin tran;
		exec z.usp_TraceAssertOwner @TraceName, @TraceID;
		if @TraceName is null and @TraceID is null
		begin
			throw 50000, N'Either @TraceName or @TraceID must be provided.', 1;
		end
		declare @ResolvedTraceID int;
		select @ResolvedTraceID = TraceID
		from z.v_TraceOwned
		where (@TraceName is null or Name = @TraceName) and (@TraceID is null or TraceID = @TraceID);
		select @TraceID = @ResolvedTraceID;
		if not exists(select 1 from z.Trace with (updlock, holdlock) where TraceID = @TraceID and CreatorSessionID = @@spid
			and CreatorLoginTime = (select login_time from sys.dm_exec_sessions where session_id = @@spid))
			throw 50000, N'The selected trace registration changed before configuration.', 1;
		if not exists(select 1 from z.v_TraceOwned where TraceID = @TraceID and Status = 'Stopped')
		begin
			throw 50000, N'Stop the selected native trace before changing its configuration.', 1;
		end
		if exists(select 1 from sys.fn_trace_geteventinfo(@TraceID))
			throw 50000, N'Native event and filter configuration is fixed after binding begins; close and recreate this trace to change it.', 1;
		declare @Events table(EventID int primary key);
		if @EventList is not null
		begin
			if trim(@EventList) = N'all'
				insert into @Events(EventID) select TraceEventID from z.v_TraceEvent;
			else
			begin
				if trim(@EventList) = N'' or exists
				(
					select 1 from string_split(@EventList, N',') s
					where trim(s.value) = N'' or not exists(select 1 from z.v_TraceEvent v where v.EventName = trim(s.value))
				)
				begin
					throw 50000, N'@EventList must contain comma-separated catalog names without empty or unknown values.', 1;
				end
				insert into @Events(EventID)
					select distinct v.TraceEventID from z.v_TraceEvent v
						inner join string_split(@EventList, N',') s on v.EventName = trim(s.value);
			end
		end
		delete t from z.TraceEventColumn t inner join @Events e on e.EventID = t.EventID where t.TraceID = @TraceID;
		delete t from z.TraceTrigger t inner join z.v_TraceEvent v on v.EventName = t.EventName
			inner join @Events e on e.EventID = v.TraceEventID where t.TraceID = @TraceID;
		delete t from z.TraceEvent t inner join @Events e on e.EventID = t.EventID where t.TraceID = @TraceID;
		update z.Trace set ModificationDate = getdate() where TraceID = @TraceID;
		commit;
	end try
	begin catch
		if @@trancount > 0 rollback;
		throw;
	end catch;
end
go
