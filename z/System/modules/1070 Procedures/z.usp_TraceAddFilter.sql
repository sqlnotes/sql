create or alter procedure z.usp_TraceAddFilter
(
	@TraceName varchar(128) = null,
	@TraceID int = null,
	@ColumnName varchar(128) = null,
	@ColumnID int = null,
	@LogicOperator varchar(3) = 'and', -- can be 'and' and 'or'
	@ComparisonOperator varchar(7) = '=', -- can be =, <>, >, <, >=, <=, like, not like
	@Value sql_variant
)
as
begin
	set nocount, xact_abort on
	if @Value is null
		return
	declare @LogicOperatorInt int, @ComparisonOperatorInt int

	if @TraceID is null and @TraceName is null
	begin
		raiserror('Either @TraceName or @TraceID must be provided', 16, 1)
		return
	end

	if @ColumnName is null and @ColumnID is null
	begin
		raiserror('Either @ColumnName or @ColumnID must be provided', 16, 1)
		return
	end

	select @TraceID = TraceID
	from z.v_Trace
	where (@TraceID is null or TraceID = @TraceID)
		and (@TraceName is null or Name = @TraceName)
		and Status = 'Stopped'
	if @@rowcount = 0
	begin
		raiserror('No stopped trace found', 16, 1)
		return
	end

	if @LogicOperator not in ('and', 'or')
	begin
		raiserror('@LogicOperator must be and, or.', 16, 1)
		return
	end
	select @ComparisonOperator = replace(@ComparisonOperator, ' ', '')
	if @ComparisonOperator not in ('=', '!=', '<>', '>', '<', '>=', '<=', 'like', 'notlike')
	begin
		raiserror('@LogicOperator must be =, !=, <>, >, <, >=, <=, like, not like.', 16, 1)
		return
	end
	declare @SQL nvarchar(max)
	select	@ColumnID = ColumnID, @ColumnName = ColumnName,
			@SQL = 'declare @Value ' + replace(Definition, 'max', 256) + ' = cast(@v as ' + Definition + ')
exec sp_trace_setfilter  @traceid = @TraceID, @columnid = @ColumnID, @logical_operator = @LogicOperatorInt, @comparison_operator = @ComparisonOperatorInt, @value = @Value'
	from z.v_TraceColumn
	where (@ColumnID is null or ColumnID = @ColumnID)
		and (@ColumnName is null or ColumnName = @ColumnName)
		and IsFilterable = 1
	if @@rowcount = 0
	begin
		print 'No filters added, or colum is not filterable'
		return
	end
	--print @SQL
	select	@LogicOperatorInt = case when @LogicOperator = 'and' then 0 else 1 end,
			@ComparisonOperatorInt =	case @ComparisonOperator
											when '=' then 0
											when '!=' then 1
											when '<>' then 1
											when '>' then 2
											when '<' then 3
											when '>=' then 4
											when '<=' then 5
											when 'like' then 6
											when 'notlike' then 7
										end
	exec sp_executesql @SQL, N'@TraceID int, @ColumnID int, @LogicOperatorInt int, @ComparisonOperatorInt int, @V sql_variant', @TraceID, @ColumnID, @LogicOperatorInt, @ComparisonOperatorInt, @Value
	if not exists(
					select *
					from sys.fn_trace_geteventinfo(@TraceID)
					where columnid = @ColumnID
				)
	begin
		exec z.usp_TraceAddColumns @TraceID = @TraceID, @EventColumnList = @ColumnName
	end
end
go
