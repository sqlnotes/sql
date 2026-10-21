create or alter procedure z.usp_TraceRemoveTrigger
(
	@TraceName nvarchar(128) = null,
	@TraceID int = null,
	@EventName nvarchar(128) = N'all'
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
	delete from z.TraceTrigger where TraceID = @TraceID and EventName = @EventName;
	update z.Trace set ModificationDate = getdate() where TraceID = @TraceID;
end
go
