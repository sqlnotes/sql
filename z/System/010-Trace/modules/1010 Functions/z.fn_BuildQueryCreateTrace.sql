create or alter function z.fn_BuildQueryCreateTrace
(
	@TraceID int
)
returns table
return
(
	-- TraceID identifies a logical definition, not a sys.traces ID.
	select row_number() over(order by Phase, SortKey) Ordinal, Script
	from
	(
		select 0 Phase, cast(0 as bigint) SortKey,
			cast(N'exec z.usp_TraceCreate @TraceName = N' + quotename(t.Name, '''')
				+ N', @Description = ' + isnull(N'N''' + replace(t.Description, '''', '''''') + N'''', N'null')
				+ N', @ReceivingTable = N''' + replace(t.ReceivingTable, '''', '''''') + N''';' as nvarchar(max)) Script
		from z.Trace t where t.TraceID = @TraceID
		union all
		select 1, e.EventID,
			cast(N'exec z.usp_TraceAddEvents @TraceName = N' + quotename(t.Name, '''')
				+ N', @EventList = N''' + replace(v.name, '''', '''''')
				+ N''', @EventColumnList = ' + isnull(N'N''' + c.Columns + N'''', N'null') + N';' as nvarchar(max))
		from z.Trace t inner join z.TraceEvent e on e.TraceID = t.TraceID
			inner join sys.trace_events v on v.trace_event_id = e.EventID
			outer apply
			(
				select string_agg(cast(replace(v.name, '''', '''''') as nvarchar(max)), N',') within group(order by c.ColumnID) Columns
				from z.TraceEventColumn c inner join sys.trace_columns v on v.trace_column_id = c.ColumnID
				where c.TraceID = e.TraceID and c.EventID = e.EventID
			) c
		where t.TraceID = @TraceID
		union all
		select 2, f.FilterOrdinal,
			cast(N'exec z.usp_TraceAddFilter @TraceName = N' + quotename(t.Name, '''')
				+ N', @ColumnName = N' + quotename(c.name, '''')
				+ N', @LogicOperator = ''' + f.LogicOperator + N''', @ComparisonOperator = ''' + f.ComparisonOperator
				+ N''', @Value = ' + case when c.type_name = N'image'
					then convert(nvarchar(max), convert(varbinary(8000), f.Value), 1)
					when c.type_name = N'datetime' then N'N''' + convert(nvarchar(30), convert(datetime, f.Value), 121) + N''''
					else N'N''' + replace(convert(nvarchar(max), f.Value), '''', '''''') + N'''' end + N';' as nvarchar(max))
		from z.Trace t inner join z.TraceFilter f on f.TraceID = t.TraceID
			inner join sys.trace_columns c on c.trace_column_id = f.ColumnID
		where t.TraceID = @TraceID
		union all
		select 3, row_number() over(order by c.EventName),
			cast(N'exec z.usp_TraceSetTrigger @TraceName = N' + quotename(t.Name, '''')
				+ N', @EventName = N' + quotename(c.EventName, '''')
				+ N', @ProcedureName = N''' + replace(c.ProcedureName, '''', '''''') + N''';' as nvarchar(max))
		from z.Trace t inner join z.TraceTrigger c on c.TraceID = t.TraceID where t.TraceID = @TraceID
		union all
		select 4, 0, cast(N'exec z.usp_TraceStart @TraceName = N' + quotename(Name, '''') + N';' as nvarchar(max))
		from z.Trace where TraceID = @TraceID and IsEnabled = 1
	) s
)
go
