create or alter procedure z.usp_TraceAddFilter
(
	@TraceName nvarchar(128) = null,
	@TraceID int = null,
	@ColumnName nvarchar(128) = null,
	@ColumnID int = null,
	@LogicOperator varchar(3) = 'and',
	@ComparisonOperator varchar(8) = '=',
	@Value sql_variant
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
	if @Value is null return;
	select @LogicOperator = lower(trim(@LogicOperator)), @ComparisonOperator = lower(replace(@ComparisonOperator, ' ', ''));
	if @LogicOperator is null or @LogicOperator not in ('and', 'or')
	begin
		throw 50000, N'@LogicOperator must be and, or.', 1;
	end
	if @ComparisonOperator is null or @ComparisonOperator not in ('=', '!=', '<>', '>', '<', '>=', '<=', 'like', 'notlike')
	begin
		throw 50000, N'Unsupported trace comparison operator.', 1;
	end
	if @ComparisonOperator = '!=' select @ComparisonOperator = '<>';
	declare @Definition nvarchar(128), @DataType sysname, @SQL nvarchar(max), @TypedValue sql_variant;
	select @ColumnID = ColumnID, @Definition = Definition, @DataType = DataType
	from z.v_TraceColumn
	where (@ColumnID is null or ColumnID = @ColumnID) and (@ColumnName is null or ColumnName = @ColumnName)
		and (@ColumnID is not null or @ColumnName is not null) and IsFilterable = 1;
	if @Definition is null
	begin
		throw 50000, N'No matching filterable trace column found.', 1;
	end
	if @ComparisonOperator in ('like', 'notlike') and @DataType not in ('nvarchar', 'varchar', 'nchar', 'char')
	begin
		throw 50000, N'LIKE filters require a character trace column.', 1;
	end
	if @Definition = N'nvarchar(max)'
	begin
		if datalength(convert(nvarchar(max), @Value)) > 8000
		begin
			throw 50000, N'Trace filter text exceeds the sql_variant limit of 4000 Unicode characters.', 1;
		end
		select @Definition = N'nvarchar(4000)';
	end
	if @Definition = N'varbinary(max)' select @Definition = N'varbinary(8000)';
	-- Type definitions come only from SQL Server's trace column catalog.
	select @SQL = N'select @TypedValue = convert(sql_variant, convert(' + @Definition + N', @Value));';
	exec sys.sp_executesql @SQL, N'@Value sql_variant, @TypedValue sql_variant output', @Value, @TypedValue output;
	if @DataType in ('nvarchar', 'varchar', 'nchar', 'char')
		and datalength(convert(nvarchar(max), @TypedValue)) < datalength(convert(nvarchar(max), @Value))
	begin
		throw 50000, N'Trace filter value exceeds the selected column length.', 1;
	end
	insert into z.TraceFilter(TraceID, FilterOrdinal, ColumnID, LogicOperator, ComparisonOperator, Value)
		select @TraceID, isnull(max(FilterOrdinal), 0) + 1, @ColumnID, @LogicOperator, @ComparisonOperator, @TypedValue
		from z.TraceFilter where TraceID = @TraceID;
	update z.Trace set ModificationDate = getdate() where TraceID = @TraceID;
end
go
