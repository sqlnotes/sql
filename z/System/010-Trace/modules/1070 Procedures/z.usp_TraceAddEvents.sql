create or alter procedure z.usp_TraceAddEvents
(
	@TraceName nvarchar(128) = null,
	@TraceID int = null,
	@EventList nvarchar(max) = null,
	@EventColumnList nvarchar(max) = null
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
	declare @Events table(EventID int primary key);
	if @EventList is not null
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
	declare @Columns table(ColumnID int primary key);
	if @EventColumnList is not null
	begin
		if trim(@EventColumnList) = N'all'
			insert into @Columns(ColumnID) select ColumnID from z.v_TraceColumn;
		else
		begin
			if trim(@EventColumnList) = N'' or exists
			(
				select 1 from string_split(@EventColumnList, N',') s
				where trim(s.value) = N'' or not exists(select 1 from z.v_TraceColumn v where v.ColumnName = trim(s.value))
			)
			begin
				throw 50000, N'@EventColumnList must contain comma-separated catalog names without empty or unknown values.', 1;
			end
			insert into @Columns(ColumnID)
				select distinct v.ColumnID from z.v_TraceColumn v
					inner join string_split(@EventColumnList, N',') s on v.ColumnName = trim(s.value);
		end
	end
	if not exists(select 1 from @Events) return;
	if @EventColumnList is null
		insert into @Columns(ColumnID) select distinct ColumnID from z.TraceEventColumn where TraceID = @TraceID;
	if not exists(select 1 from @Columns where ColumnID = 12) insert into @Columns(ColumnID) values(12);
	insert into z.TraceEvent(TraceID, EventID)
		select @TraceID, e.EventID from @Events e
		where not exists(select 1 from z.TraceEvent t where t.TraceID = @TraceID and t.EventID = e.EventID);
	insert into z.TraceEventColumn(TraceID, EventID, ColumnID)
		select @TraceID, e.EventID, c.ColumnID
		from @Events e cross join @Columns c
			inner join sys.trace_event_bindings b on b.trace_event_id = e.EventID and b.trace_column_id = c.ColumnID
		where not exists(select 1 from z.TraceEventColumn t where t.TraceID = @TraceID and t.EventID = e.EventID and t.ColumnID = c.ColumnID);
	update z.Trace set ModificationDate = getdate() where TraceID = @TraceID;
end
go
