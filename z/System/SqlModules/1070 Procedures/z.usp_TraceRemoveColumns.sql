create or alter procedure z.usp_TraceRemoveColumns
(
	@TraceName varchar(128) = null,
	@TraceID int = null,
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
	declare @Columns table(ColumnID int primary key with(ignore_dup_key=on))
	begin try
	insert into @Columns(ColumnID)
		exec(@TraceEventColumnQuery)
	if @EventColumnList = 'all'
	begin
		insert into @Columns(ColumnID)
			exec(@TraceEventColumnQuery)
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
	delete @Columns where ColumnID = 12
	
	if not exists(select 1 from @Columns)
	begin
		print 'No columns added.'
		return
	end
	declare c cursor static local for
		select t.Name, t.TraceID, i.TraceEventID, e.ColumnID
		from z.v_Trace t
			cross apply(
							select eventid TraceEventID, i.columnid ColumnID
							from sys.fn_trace_geteventinfo(t.TraceID) i
						) i
			inner join @Columns e on e.ColumnID = i.ColumnID
		where (@TraceName is null or Name = @TraceName)
			and (@TraceID is null or TraceID = @TraceID)
			and Status = 'Stopped'
	open c
	fetch next from c into @TraceName, @TraceID, @EventID, @ColumnID
	while @@fetch_status = 0
	begin
		exec sp_trace_setevent @traceid = @TraceID, @eventid = @EventID, @columnid = @ColumnID, @on = 0
		fetch next from c into @TraceName, @TraceID, @EventID, @ColumnID
	end
	close c
	deallocate c
end
go
--exec z.usp_CreateTrace 'abc'
--select * from z.v_Trace
--exec z.usp_TraceRemoveColumns @TraceName = 'abc', @TraceEventColumnQuery = 'select ColumnID from z.v_TraceColumn where ColumnID in(2,3)', @EventColumnList = 'IndexID'

--select * from z.v_TraceDefinition where TraceID = 3 and IsEventSelected = 1

--select * from z.v_TraceColumn where ColumnID in(1,2,3)



--select * from z.v_TraceEventColumn where TraceEventID in(12,13)