/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/010-Trace/modules/1070%20Procedures/z.usp_TraceStart.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/010-Trace/docs/reference/z.usp_TraceStart.md

Applies native event bindings and filters, then starts the selected physical traces.
*/
create or alter procedure z.usp_TraceStart
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
		throw 50000, N'Trace start requires no existing transaction.', 1;
	end;
	exec z.usp_TraceAssertOwner @TraceName, @TraceID;
	declare @SelectedTraceID int, @EventID int, @ColumnID int,
		@ReturnCode int, @LogicalOperator int, @ComparisonOperator int, @Value sql_variant, @Definition nvarchar(128),
		@SQL nvarchar(max), @Message nvarchar(2048), @Operation nvarchar(128),
		@CreatorLoginTime datetime = (select login_time from sys.dm_exec_sessions where session_id = @@spid);
	declare t cursor local static read_only for
		select TraceID from z.v_TraceOwned
		where (@TraceName is null or Name = @TraceName) and (@TraceID is null or TraceID = @TraceID) and Status <> 'Running';
	open t;
	fetch next from t into @SelectedTraceID;
	while @@fetch_status = 0
	begin
		begin try
			begin tran;
			if not exists(select 1 from z.Trace with (updlock, holdlock) where TraceID = @SelectedTraceID
				and CreatorSessionID = @@spid and CreatorLoginTime = @CreatorLoginTime)
			begin
				select @Message = concat(N'Native trace ', @SelectedTraceID, N' registration changed before start.');
				throw 50000, @Message, 1;
			end;
			if not exists(select 1 from sys.traces where id = @SelectedTraceID and is_rowset = 1 and stop_time is null and status = 0)
			begin
				select @Message = concat(N'Native trace ', @SelectedTraceID, N' is unavailable; close its registration and create a new trace.');
				throw 50000, @Message, 1;
			end;
			if not exists(select 1 from z.TraceEvent where TraceID = @SelectedTraceID)
			begin
				select @Message = concat(N'Select at least one event before starting native trace ', @SelectedTraceID, N'.');
				throw 50000, @Message, 1;
			end;
			-- Native rowset SPID bindings cannot be removed. Configuration is frozen
			-- after native event binding begins; repeated Start reapplies the same bindings.
			select @Operation = N'configure events';
			declare e cursor local static read_only for
				select EventID, ColumnID from z.TraceEventColumn where TraceID = @SelectedTraceID order by EventID, ColumnID;
			open e;
			fetch next from e into @EventID, @ColumnID;
			while @@fetch_status = 0
			begin
				exec @ReturnCode = sys.sp_trace_setevent @SelectedTraceID, @EventID, @ColumnID, 1;
				if @ReturnCode <> 0
				begin
					select @Message = concat(N'Native trace ', @SelectedTraceID, N': ', @Operation, N' failed for event ', @EventID, N', column ', @ColumnID, N'; return code ', @ReturnCode, N'.');
					throw 50000, @Message, 1;
				end;
				fetch next from e into @EventID, @ColumnID;
			end;
			close e;
			deallocate e;
			select @Operation = N'clear filters';
			exec @ReturnCode = sys.sp_trace_setfilter @SelectedTraceID, null, 0, 0, null;
			if @ReturnCode <> 0
			begin
				select @Message = concat(N'Native trace ', @SelectedTraceID, N': ', @Operation, N' failed; return code ', @ReturnCode, N'.');
				throw 50000, @Message, 1;
			end;
			-- Native filters group predicates by column; separate columns are combined by SQL Trace.
			select @Operation = N'configure filters';
			declare f cursor local static read_only for
				select f.ColumnID, case f.LogicOperator when 'and' then 0 else 1 end,
					case f.ComparisonOperator when '=' then 0 when '<>' then 1 when '>' then 2 when '<' then 3 when '>=' then 4 when '<=' then 5 when 'like' then 6 when 'notlike' then 7 end,
					f.Value, case c.Definition when N'nvarchar(max)' then N'nvarchar(4000)' when N'varbinary(max)' then N'varbinary(8000)' else c.Definition end
				from z.TraceFilter f inner join z.v_TraceColumn c on c.ColumnID = f.ColumnID
				where f.TraceID = @SelectedTraceID order by f.ColumnID, f.FilterOrdinal;
			open f;
			fetch next from f into @ColumnID, @LogicalOperator, @ComparisonOperator, @Value, @Definition;
			while @@fetch_status = 0
			begin
				select @SQL = N'declare @FilterValue ' + @Definition + N' = convert(' + @Definition + N', @Value);
exec @ReturnCode = sys.sp_trace_setfilter @TraceID, @ColumnID, @LogicalOperator, @ComparisonOperator, @FilterValue;';
				exec sys.sp_executesql @SQL,
					N'@TraceID int, @ColumnID int, @LogicalOperator int, @ComparisonOperator int, @Value sql_variant, @ReturnCode int output',
					@SelectedTraceID, @ColumnID, @LogicalOperator, @ComparisonOperator, @Value, @ReturnCode output;
				if @ReturnCode <> 0
				begin
					select @Message = concat(N'Native trace ', @SelectedTraceID, N': ', @Operation, N' failed for column ', @ColumnID, N'; return code ', @ReturnCode, N'.');
					throw 50000, @Message, 1;
				end;
				fetch next from f into @ColumnID, @LogicalOperator, @ComparisonOperator, @Value, @Definition;
			end;
			close f;
			deallocate f;
			select @Operation = N'start';
			exec @ReturnCode = sys.sp_trace_setstatus @SelectedTraceID, 1;
			if @ReturnCode <> 0
			begin
				select @Message = concat(N'Native trace ', @SelectedTraceID, N': start failed; return code ', @ReturnCode, N'.');
				throw 50000, @Message, 1;
			end;
			update z.Trace set ModificationDate = getdate()
			where TraceID = @SelectedTraceID and CreatorSessionID = @@spid and CreatorLoginTime = @CreatorLoginTime;
			commit;
		end try
		begin catch
			if @@trancount > 0 rollback;
			if cursor_status('local', 'e') >= 0 close e;
			if cursor_status('local', 'e') >= -1 deallocate e;
			if cursor_status('local', 'f') >= 0 close f;
			if cursor_status('local', 'f') >= -1 deallocate f;
			select @Message = concat(N'Native trace ', @SelectedTraceID, N' failed during ', @Operation, N': ', error_message());
			print @Message;
			throw;
		end catch;
		fetch next from t into @SelectedTraceID;
	end;
	close t;
	deallocate t;
end;
go
