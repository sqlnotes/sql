create or alter procedure z.usp_TraceAddEvents
(
	@TraceName varchar(128) = null,
	@TraceID int = null,
	@TraceEventQuery nvarchar(max) = null,
	@EventList nvarchar(max) = null,
	@TraceEventColumnQuery nvarchar(max) = null,
	@EventColumnList nvarchar(max) = null
)
as
begin
	set nocount, xact_abort on
	if @TraceName is null and @TraceID is null
	begin
		raiserror('Either @TraceName or @TraceID must be provided', 16, 1)
		return;
	end
	declare @Error varchar(8000), @EventID int, @ColumnID int
	declare @Trace table(TraceID int primary key with(ignore_dup_key=on))
	declare @Events table(EventID int primary key with(ignore_dup_key=on))
	declare @Columns table(ColumnID int primary key with(ignore_dup_key=on))

	insert into @Trace(TraceID)
		select t.TraceID
		from z.v_trace t
		where (@TraceName is null or t.Name = @TraceName)
			and (@TraceID is null or t.TraceID = @TraceID)
			and Status = 'Stopped'
	if @@rowcount = 0
	begin
		print 'No trace found.'
		return
	end
	begin try
	insert into @Events(EventID)
		exec(@TraceEventQuery)

	if @EventList is not null
	begin
		select @TraceEventQuery = 'select TraceEventID from  z.v_TraceEvent where (0=1)'
			+ (
					select ' or (EventName like ''%' + replace(ltrim(rtrim(value)), '''', '''''' )+ '%'')'
					from string_split(@EventList, ',') a
					for xml path(''), type
				).value('.', 'nvarchar(max)')
		insert into @Events(EventID)
			exec(@TraceEventQuery)
	end
	end try
	begin catch
		select @Error = 'Please ensure you use "select TraceEventID from  z.v_TraceEvent where ..." as TraceEventQuery
' + isnull(error_message(), '')
		raiserror(@Error, 16, 1)
		return
	end catch
	if not exists(select * from @Events)
	begin
		print 'No events added.'
		return
	end
	
	begin try
	insert into @Columns(ColumnID)
		exec(@TraceEventColumnQuery)
	if @EventColumnList = 'all'
	begin
		insert into @Columns(ColumnID)
			select ColumnID 
			from  z.v_TraceColumn
	end
	if @EventColumnList is not null
	begin
		select @TraceEventColumnQuery = 'select ColumnID from  z.v_TraceColumn where (0=1)'
			+ (
					select ' or (ColumnName like ''%' + replace(ltrim(rtrim(value)), '''', '''''' )+ '%'')'
					from string_split(@EventColumnList, ',') a
					for xml path(''), type
				).value('.', 'nvarchar(max)')
		insert into @Columns(ColumnID)
			exec(@TraceEventColumnQuery)	
	end
	end try
	begin catch
		select @Error = 'Please ensure you use "select ColumnID from z.v_TraceColumn where ..." as TraceEventColumnQuery
' + isnull(error_message(), '')
		raiserror(@Error, 16, 1)
		return
	end catch

	if @EventColumnList is null
	begin
		insert into @Columns(ColumnID)
			select c.columnid
			from @Trace t
				cross apply sys.fn_trace_geteventinfo(t.TraceID) c
	end
	insert into @Columns(ColumnID) values(12)

	declare c cursor static local for
		select t.TraceID, eb.trace_event_id, eb.trace_column_id
		from @Trace t
			cross join sys.trace_event_bindings eb 
			inner join @Events e 
				cross join @Columns c 
					on c.ColumnID = eb.trace_column_id and e.EventID = eb.trace_event_id
	open c
	fetch next from c into @TraceID, @EventID, @ColumnID
	while @@fetch_status = 0
	begin
		exec sp_trace_setevent @traceid = @TraceID, @eventid = @EventID, @columnid = @ColumnID, @on = 1
		fetch next from c into @TraceID, @EventID, @ColumnID
	end
	close c
	deallocate c
end
go
--exec z.usp_CreateTrace 'abc'
--select * from z.v_Trace
--exec z.usp_TraceAddEvents @TraceName = 'abc', @TraceEventQuery = 'select TraceEventID
--from  z.v_TraceEvent 
--where EventName in (''SQL:BatchCompleted'', ''SQL:BatchStarting'')', @EventList = 'Assembly Load'

--select * from z.v_TraceDefinition where TraceID = 3 and IsEventSelected = 1
--exec z.usp_TraceAddEvents @TraceName = 'abc', @EventList = 'SP:Completed'
--exec z.usp_TraceAddEvents @TraceName = 'abc', @EventList = 'SP:Recompile'
--select * from z.v_TraceMetaData

--select * from 