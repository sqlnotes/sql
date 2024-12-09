create or alter function z.fn_BuildQueryCreateTrace
(
	@TraceID int
)
returns table
return(
		select 1 as Ordinal, cast('exec z.usp_TraceCreate @TraceName = ' +quotename(isnull(mt.Name, '<TraceName>'), '''')+ ', @Description=' + isnull('''' + replace(mt.Description, '''', '''''') + '''', 'null') as nvarchar(max)) Script
		from sys.traces t
			left join z.Trace mt on mt.TraceID = t.id
		where t.id = @TraceID
		union all
		select row_number() over(order by Events, Columns) + 1 RowNumber, 'exec z.usp_TraceAddEvents @TraceName=' + quotename(t.TraceName, '''') + ', @EventList = ''' + t.Events + ''', @EventColumnList=''' + t.Columns + ''''
		from(
				select @TraceID TraceID, t.TraceName, string_agg(cast(t.EventName as varchar(max)), ',') within group(order by t.EventName) Events, t.Columns
				from (
						select isnull(t.Name, '<TraceName>') TraceName, e.name EventName, string_agg(cast(c.name as varchar(max)), ',') within group(order by c.name) Columns
						from sys.fn_trace_geteventinfo(@TraceID) i
							inner join sys.trace_events e on e.trace_event_id = i.eventid
							inner join sys.trace_columns c on i.columnid  = c.trace_column_id
							left join z.Trace t on t.TraceID = @TraceID
						group by e.name, t.Name
					) t
				group by t.Columns, t.TraceName
			) t
		union all
		select row_number() over(order by ColumnName)  + 1000 Ordinal, Script
		from (
				select distinct c.name ColumnName, 'exec z.usp_TraceAddFilter @TraceName = ' +quotename(isnull(t.Name, '<TraceName>'), '''') 
					+ ', @ColumnName = ' +quotename(c.name collate database_default, '''')
					+ ', @LogicOperator = ''' + case when i.logical_operator = 0 then 'and' else 'or' end+ ''''
					+ ', @ComparisonOperator = ''' 
						+	case i.comparison_operator
								when 0 then '='
								when 1 then '<>'
								when 2 then '>'
								when 3 then '<'
								when 4 then '>='
								when 5 then '<='
								when 6 then 'Like'
								else 'Not like'
							end + ''''
					+ ', @Value = ' 
					+	case c.type_name
							when 'datetime' then quotename(convert(nvarchar(max), cast(i.value as datetime), 121), '''')
							when 'image' then '''' + convert(nvarchar(max), cast(i.value as varbinary(max)), 1) + ''''
							else '''' + replace(cast(i.value as nvarchar(max)), '''', '''''') + ''''
						end Script
				from sys.fn_trace_getfilterinfo(@TraceID) i
					inner join sys.trace_columns c on i.columnid  = c.trace_column_id
					left join z.Trace t on t.TraceID = @TraceID
			) s
		union all
		select 9999 as RowNumber, cast('exec z.usp_TraceStart @TraceName = ' +quotename(isnull(mt.Name, '<TraceName>'), '''') as nvarchar(max))
		from sys.traces t
			left join z.Trace mt on mt.TraceID = t.id
		where t.id = @TraceID
)
go
