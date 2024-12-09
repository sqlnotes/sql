create or alter procedure z.usp_TraceStart
(
	@TraceName varchar(128) = null,
	@TraceID int = null,
	@CurrentSessionOnly bit = 1
)
as
begin
	set nocount, xact_abort on
	declare @Status varchar(16)
	declare c cursor static local for
		select Name, TraceID, Status
		from z.v_Trace
		where (@TraceName is null or Name = @TraceName)
			and (@TraceID is null or TraceID = @TraceID)
			and (@CurrentSessionOnly = 0 or CreatorSessionID = @@spid)
	open c
	fetch next from c into @TraceName, @TraceID, @Status
	while @@fetch_status = 0
	begin
		if @Status <> 'Not Available'
		begin
			exec sp_trace_setstatus @TraceID, 1
		end
		fetch next from c into @TraceName, @TraceID, @Status
	end
	close c
	deallocate c
end
