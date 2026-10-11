create or alter procedure z.usp_TraceRefreshMetaData
as
begin
	set nocount on
	begin try
	declare @TraceMetaDataViewName sysname = 'v_TraceMetaData', @SQL nvarchar(max), @h1 sql_variant, @h2 sql_variant,
			@TraceDefinitionViewName sysname = 'v_TraceDefinition'

	select @SQL = 'create or alter view z.' + @TraceMetaDataViewName + '
as
	select tc.name CategoryName, te.name EventName, te.trace_event_id TraceEventID' 
	+ (
		select ', isnull(max(case when b.trace_column_id = ' + cast(trace_column_id as nvarchar(max)) + ' then 1 end), 0) as ' + quotename(name) 
		from sys.trace_columns 
		order by trace_column_id 
		for xml path(''), type
	).value('.', 'nvarchar(max)') + '
	from sys.trace_categories tc
		inner join sys.trace_events te on te.category_id = tc.category_id
		inner join sys.trace_event_bindings b on b.trace_event_id = te.trace_event_id
	group by te.name, te.trace_event_id, tc.name
;';
	--exec z.usp_PrintString @SQL
	select @h1 = cast(cast(hashbytes('MD5', @SQL) as uniqueidentifier) as sql_variant)
	select @h2 = (select value from sys.fn_listextendedproperty('Code Hash', N'SCHEMA', 'z', N'VIEW', @TraceMetaDataViewName, null, null))
	if @h1 <> isnull(@h2, cast(0x0 as uniqueidentifier))
	begin
		exec(@SQL)
		if @h2 is not null
		begin
			exec sys.sp_dropextendedproperty @name = 'Code Hash', @level0type = N'SCHEMA', @level0name = 'z', @level1type = N'VIEW', @level1name = @TraceMetaDataViewName
		end
		exec sys.sp_addextendedproperty @name = 'Code Hash', @value = @h1 ,@level0type = N'SCHEMA', @level0name = 'z', @level1type = N'VIEW', @level1name = @TraceMetaDataViewName
	end

	select @SQL = 'create or alter view z.' + @TraceDefinitionViewName + '
as
select t.id as TraceID, t.status IsActive, tc.name CategoryName, te.name EventName, te.trace_event_id TraceEventID, case when i.eventid is not null then 1 else 0 end IsEventSelected' 
	+ (
		select ', max(case when i.columnid = ' + cast(trace_column_id as nvarchar(max)) + ' then isnull(f.Filter, '''') end) as ' + quotename(name) 
		from sys.trace_columns 
		order by trace_column_id 
		for xml path(''), type
	).value('.', 'nvarchar(max)') + '
from sys.trace_categories tc
	left join sys.trace_events te on te.category_id = tc.category_id
	cross apply sys.traces t
	outer apply (
					select i.columnid, i.eventid
					from sys.fn_trace_geteventinfo(t.id) i
					where te.trace_event_id = i.eventid
				) i
	outer apply (
					select (
								select  case f.logical_operator 
											when 0 then '' and ''
											else '' or ''
										end  + ''('' 
										+ tc.name + '' ''  
											+ case f.comparison_operator
												when 0 then ''='' --''Equal''
												when 1 then ''<>'' --''Not equal''
												when 2 then ''>'' --''Greater than''
												when 3 then ''<'' --''Less than''
												when 4 then ''>='' --''Greater than or equal''
												when 5 then ''<='' --''Less than or equal''
												when 6 then ''Like''
												else ''Not like''
											end + '' '' + 
											
											case tc.type_name
												when ''datetime'' then convert(nvarchar(max), cast(f.value as datetime), 121)
												when ''image'' then convert(nvarchar(max), cast(f.value as varbinary(max)), 1)
												else cast(f.value as nvarchar(max))
											end


										+'')''
								from sys.fn_trace_getfilterinfo(t.id) f
									inner join sys.trace_columns tc on tc.trace_column_id = f.columnid
								where f.columnid = i.columnID
								for xml path(''''), type
						).value(''.'', ''nvarchar(max)'') Filter
				) f
group by t.id, t.status, te.trace_event_id, te.name, tc.name, i.eventid
'
	--exec z.usp_PrintString @SQL
	select @h1 = cast(cast(hashbytes('MD5', @SQL) as uniqueidentifier) as sql_variant)
	select @h2 = (select value from sys.fn_listextendedproperty('Code Hash', N'SCHEMA', 'z', N'VIEW', @TraceDefinitionViewName, null, null))
	if @h1 <> isnull(@h2, cast(0x0 as uniqueidentifier))
	begin
		exec(@SQL)
		if @h2 is not null
		begin
			exec sys.sp_dropextendedproperty @name = 'Code Hash', @level0type = N'SCHEMA', @level0name = 'z', @level1type = N'VIEW', @level1name = @TraceDefinitionViewName
		end
		exec sys.sp_addextendedproperty @name = 'Code Hash', @value = @h1 ,@level0type = N'SCHEMA', @level0name = 'z', @level1type = N'VIEW', @level1name = @TraceDefinitionViewName
	end

	end try
	begin catch
		if @@trancount > 0
			rollback;
		throw;
	end catch
end
go
--select * from z.v_TraceDefinition where TraceID = 1 and IsEventSelected = 1 order by 1, 3, 4
--select * from z.v_TraceDefinition where IsEventSelected = 1 order by 1, 3, 4
--select * from z.v_TraceMetaData order by 1,2
--select * from z.v_TraceMetaData
--select* from sys.traces
--select * from z.v_TraceDefinition where IsEventSelected = 1 and TraceID = 3 order by 1, 3, 4



--select convert(nvarchar(max), 0x1234, 1), convert(nvarchar(max),getdate(), 121)

--select distinct type_name from sys.trace_columns