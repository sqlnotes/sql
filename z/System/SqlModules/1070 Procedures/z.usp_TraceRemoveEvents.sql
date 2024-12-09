create or alter procedure z.usp_TraceRemoveEvents
(
	@TraceName varchar(128) = null,
	@TraceID int = null,
	@TraceEventQuery nvarchar(max) = null,
	@EventList nvarchar(max) = null
)
as
begin
	set nocount, xact_abort on
	
	declare @Error varchar(8000), @EventID int, @ColumnID int
	declare @Events table(EventID int primary key with(ignore_dup_key=on))
	begin try
	insert into @Events(EventID)
		exec(@TraceEventQuery)
	if @EventList is not null
	begin
		select @TraceEventQuery =	case when @EventList <> 'All' then 'select TraceEventID from  z.v_TraceEvent where (0=1)'
			+ (
					select ' or (EventName like ''%' + replace(ltrim(rtrim(value)), '''', '''''' )+ '%'')'
					from string_split(@EventList, ',') a
					for xml path(''), type
				).value('.', 'nvarchar(max)')
										else 'select TraceEventID from  z.v_TraceEvent'
									end
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
	if not exists(select 1 from @Events)
	begin
		print 'No events removed.'
		return
	end
	declare c cursor static local for
		select distinct t.Name, t.TraceID, e.EventID
		from z.v_Trace t
			cross apply sys.fn_trace_geteventinfo(t.TraceID) i
			inner join @Events e on e.EventID = i.eventid
		where (@TraceName is null or Name = @TraceName)
			and (@TraceID is null or TraceID = @TraceID)
			and Status = 'Stopped'
	open c
	fetch next from c into @TraceName, @TraceID, @EventID
	while @@fetch_status = 0
	begin
		exec sp_trace_setevent @traceid = @TraceID, @eventid = @EventID, @columnid = null, @on = 0
		fetch next from c into @TraceName, @TraceID, @EventID
	end
	close c
	deallocate c
end
go
--exec z.usp_TraceCreate 'abc'
--select * from z.v_Trace
--exec z.usp_TraceRemoveEvents @TraceName = 'abc', @TraceEventQuery = 'select TraceEventID
--from  z.v_TraceEvent 
--where EventName in (''SQL:BatchCompleted'', ''SQL:BatchStarting'')', @EventList = 'Assembly Load'

--exec z.usp_TraceRemoveEvents @TraceName = 'abc',@EventList = 'Assembly Load'


--exec z.usp_TraceRemoveEvents @TraceName = 'abc', @EventList = 'Assembly Load'
--select * from z.v_TraceDefinition where TraceID = 3 and IsEventSelected = 1



