create or alter procedure z.usp_TraceSetTrigger
(
	@TraceName nvarchar(128) = null,
	@TraceID int = null,
	@EventName nvarchar(128) = N'all',
	@ProcedureName nvarchar(517)
)
as
begin
	set nocount, xact_abort on;
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
	if not exists(select 1 from z.v_TraceOwned where TraceID = @TraceID and State = 'Building')
	begin
		throw 50000, N'Trace configuration requires an owned Building collector.', 1;
	end
	if @EventName is null or (@EventName <> N'all' and not exists
		(select 1 from z.TraceEvent e inner join z.v_TraceEvent v on v.TraceEventID = e.EventID where e.TraceID = @TraceID and v.EventName = @EventName))
	begin
		throw 50000, N'Callback event must be all or an event selected by the logical trace.', 1;
	end
	declare @ProcedureID int = object_id(@ProcedureName, N'P');
	if @ProcedureID is null or parsename(@ProcedureName, 3) is not null or parsename(@ProcedureName, 4) is not null
	begin
		throw 50000, N'Callback must be an existing stored procedure in the current database.', 1;
	end
	select @ProcedureName = quotename(object_schema_name(@ProcedureID)) + N'.' + quotename(object_name(@ProcedureID));
	update z.TraceTrigger set ProcedureName = @ProcedureName where TraceID = @TraceID and EventName = @EventName;
	if @@rowcount = 0 insert into z.TraceTrigger(TraceID, EventName, ProcedureName) values(@TraceID, @EventName, @ProcedureName);
	update z.Trace set ModificationDate = getdate() where TraceID = @TraceID;
end
go
