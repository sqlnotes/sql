create or alter procedure z.usp_TraceCreate
(
	@TraceName nvarchar(128) = null,
	@Description nvarchar(max) = null,
	@ReceivingTable nvarchar(128) = null,
	@TraceID int = null output
)
as
begin
	set nocount on
	declare @Status varchar(16), @ret int
	delete z.v_Trace where Status = 'Not Available'
	if @TraceName is null
		return;
	if exists(select * from z.v_Trace where Name = @TraceName and Status in ('Running'))
	begin
		raiserror('Trace %s is running.', 16, 1, @TraceName)
		return
	end
	if exists(
				select *
				from z.v_Trace
				where Name = @TraceName
					and Status in ('Stopped')
					and CreatorSessionID <> @@spid
			)
	begin
		exec z.usp_TraceClose @TraceName = @TraceName, @CurrentSessionOnly = 0
	end
	
	select @Status = Status, @TraceID = TraceID
	from z.v_Trace
	where Name = @TraceName
	if @@rowcount > 0 
	begin
		if @Status in ('Stopped')
		begin
			update z.Trace
				set Description = @Description, ModificationDate = getdate(),
					ReceivingTable = isnull(@ReceivingTable, ReceivingTable)
			where Name = @TraceName 
				and @Description is not null
				and (
						isnull(Description, '') <> isnull(@Description, '')
					or ReceivingTable <> isnull(@ReceivingTable, '')
					)
		end
		return
	end
	exec @ret = sp_trace_create @traceid = @TraceID output, @options = 1
	if @ret <> 0
	begin
		raiserror('Failed to create trace %s. Error code %d', 16, 1, @TraceName, @ret)
		return
	end
	select @ReceivingTable = isnull(@ReceivingTable, 'z.' + quotename('Trace_' + @TraceName))
	merge z.Trace t
	using (select @TraceName as Name ) s on t.Name = s.Name
	when not matched then
		insert (TraceID, Name, Description, ReceivingTable)
			values(@TraceID, @TraceName, @Description, @ReceivingTable)
	when matched then
		update set TraceID = @TraceID, Description = @Description, ModificationDate = getdate(), ReceivingTable = @ReceivingTable
	;
end
go
