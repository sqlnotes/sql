/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/010-Trace/modules/1070%20Procedures/z.usp_TraceCreate.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/010-Trace/docs/reference/z.usp_TraceCreate.md

Creates a stopped native rowset trace without a scheduled stop time.
*/
create or alter procedure z.usp_TraceCreate
(
	@TraceName nvarchar(128) = null,
	@Description nvarchar(max) = null,
	@ReceivingTable nvarchar(128) = null,
	@TraceID int = null output
)
as
begin
	set nocount, xact_abort on;
	if @@trancount > 0
	begin
		set xact_abort off;
		throw 50000, N'Trace creation requires no existing transaction.', 1;
	end;
	declare @SchemaName sysname, @TableName sysname, @QualifiedTable nvarchar(517), @ReturnCode int,
		@CreatorLoginTime datetime = (select login_time from sys.dm_exec_sessions where session_id = @@spid),
		@TraceFile nvarchar(256) = null, @MaxFileSize bigint = 5, @Message nvarchar(2048), @Allocated bit = 0;
	select @TraceID = null;
	if @TraceName is null return;
	if trim(@TraceName) = N'' throw 50000, N'@TraceName must not be empty.', 1;
	if @ReceivingTable is not null
	begin
		select @SchemaName = parsename(@ReceivingTable, 2), @TableName = parsename(@ReceivingTable, 1);
		if @SchemaName is null or @TableName is null or parsename(@ReceivingTable, 3) is not null
			or parsename(@ReceivingTable, 4) is not null or schema_id(@SchemaName) is null
			throw 50000, N'@ReceivingTable must identify a table in an existing schema in the current database.', 1;
		select @QualifiedTable = quotename(@SchemaName) + N'.' + quotename(@TableName);
		if len(@QualifiedTable) > 128 throw 50000, N'The quoted receiving table name exceeds the registry limit.', 1;
		select @ReceivingTable = @QualifiedTable;
	end;
	exec z.usp_TraceCleanup;
	select @TraceID = TraceID from z.v_TraceOwned where Name = @TraceName;
	if @TraceID is not null
	begin
		begin try
			begin tran;
			if not exists(select 1 from z.Trace with (updlock, holdlock) where TraceID = @TraceID and Name = @TraceName
				and CreatorSessionID = @@spid and CreatorLoginTime = @CreatorLoginTime)
			begin
				select @Message = concat(N'Native trace ', @TraceID, N' registration changed before updating its metadata.');
				throw 50000, @Message, 1;
			end;
			if not exists(select 1 from z.v_TraceOwned where TraceID = @TraceID and Status = 'Stopped')
				throw 50000, N'Stop or close the existing native trace before changing its metadata.', 1;
			update z.Trace set Description = isnull(@Description, Description), ReceivingTable = isnull(@ReceivingTable, ReceivingTable), ModificationDate = getdate()
			where TraceID = @TraceID and CreatorSessionID = @@spid and CreatorLoginTime = @CreatorLoginTime;
			commit;
		end try
		begin catch
			if @@trancount > 0 rollback;
			select @TraceID = null;
			throw;
		end catch;
		return;
	end;
	if @ReceivingTable is null
	begin
		select @QualifiedTable = N'[z].' + quotename(N'Trace_' + @TraceName);
		if @QualifiedTable is null or len(@QualifiedTable) > 128
			throw 50000, N'The default receiving table name exceeds the registry limit; provide a shorter @ReceivingTable.', 1;
		select @ReceivingTable = @QualifiedTable;
	end;
	begin try
		exec @ReturnCode = sys.sp_trace_create @traceid = @TraceID output, @options = 1, @tracefile = @TraceFile,
			@maxfilesize = @MaxFileSize, @stoptime = null;
		if @ReturnCode <> 0
		begin
			select @Message = concat(N'Native trace creation failed; return code ', @ReturnCode, N'.');
			throw 50000, @Message, 1;
		end;
		select @Allocated = 1;
		if not exists(select 1 from sys.traces where id = @TraceID and is_rowset = 1 and stop_time is null)
		begin
			select @Message = concat(N'Native trace ', @TraceID, N' disappeared during creation.');
			throw 50000, @Message, 1;
		end;
		insert z.Trace (TraceID, Name, Description, ReceivingTable, CreatorSessionID, CreatorLoginTime)
			values (@TraceID, @TraceName, @Description, @ReceivingTable, @@spid, @CreatorLoginTime);
	end try
	begin catch
		begin try
			if @Allocated = 1 and @TraceID is not null
				and exists(select 1 from sys.traces where id = @TraceID and is_rowset = 1 and stop_time is null)
			begin
				exec @ReturnCode = sys.sp_trace_setstatus @TraceID, 2;
				if @ReturnCode <> 0 print N'Failed to close an unregistered native trace; manual review is required.';
			end;
		end try
		begin catch
			print N'Failed to close an unregistered native trace; manual review is required.';
		end catch;
		throw;
	end catch;
end;
go
