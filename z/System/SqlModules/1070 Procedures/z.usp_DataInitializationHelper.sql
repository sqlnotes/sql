create or alter procedure z.usp_DataInitializationHelper
(
	@FullObjectName sysname,
	@ForceIdentityColumnInsert bit = 1,
	@ForceMatchedDataUpdate bit = 1,
	@PrimaryKeys varchar(max) = null,
	@ExcludedColumns varchar(max) = null
)
as
begin
	set nocount on
	declare @HasIdentityColumn bit = 0, @SQL nvarchar(max), @Data nvarchar(max), @ObjectID int = object_id(@FullObjectName)
	
	if @ObjectID is null
		return
	
	select @FullObjectName = quotename(object_schema_name(@ObjectID)) + '.' + quotename(object_name(@ObjectID))
	select @SQL = 'select * from ' + @FullObjectName
	exec z.usp_GetQueryResultToSQL @SQL, @Data output
	--exec z.usp_PrintString @Data
	select * into #SourceSchema
	from z.v_Objects
	where ObjectID = @ObjectID

	if @PrimaryKeys is not null
	begin
		update #SourceSchema set PrimaryKeyOrder = 0 where PrimaryKeyOrder <> 0
		update t
			set PrimaryKeyOrder = p.Ordinal
		from #SourceSchema t
			inner join z.fn_SplitString(@PrimaryKeys, ',') p on rtrim(ltrim(p.Value)) = t.ColumnName
	end

	delete #SourceSchema where IsTimestamp = 1 or IsComputed = 1

	delete t
	from #SourceSchema  t
		inner join z.fn_SplitString(@ExcludedColumns, ',') e on rtrim(ltrim(e.Value)) = t.ColumnName
	where t.PrimaryKeyOrder = 0

	if @ForceIdentityColumnInsert = 0
	begin
		delete #SourceSchema where IsIdentity = 1
	end

	if not exists(select * from #SourceSchema where PrimaryKeyOrder >0)
	begin
		raiserror('No primary key found', 16, 1)
		return
	end

	if exists(select * from #SourceSchema where IsIdentity = 1)
		select @HasIdentityColumn = 1
	

	select @SQL = cast('-- Initialize ' as nvarchar(max)) + @FullObjectName + '
-- exec z.usp_DataInitializationHelper @FullObjectName = ' + quotename(@FullObjectName, '''') + ' , @ForceIdentityColumnInsert = ' + iif(@ForceIdentityColumnInsert = 1, '1', '0') + ', @ForceMatchedDataUpdate = ' + iif(@ForceMatchedDataUpdate = 1, '1', '0') + ', @PrimaryKeys = ' + iif(@PrimaryKeys is null, 'null', '''' + replace(@PrimaryKeys, '''', '''''') + '''') + ', @ExcludedColumns = ' + iif(@ExcludedColumns is null, 'null', '''' + replace(@ExcludedColumns, '''', '''''') + '''') 
		+ case when @HasIdentityColumn = 1  then '
set identity_insert ' + @FullObjectName + ' on;' else '' end
		+ '
;with s as 
(
	' + @Data + '
)
merge ' + @FullObjectName + ' t
using s on '+stuff((select 'and s.'+ quotename(columnName)+'= t.'+ quotename(columnName) from #SourceSchema where PrimaryKeyOrder > 0 order by ColumnID for xml path('')), 1, 4,'')+'
when not matched then
	insert ('+stuff((select ','+ quotename(columnName) from #SourceSchema order by ColumnID for xml path('')), 1, 1,'')+')
	values('+stuff((select ',s.'+ quotename(columnName) from #SourceSchema order by ColumnID for xml path('')), 1, 1,'')+')
'
		+case when @ForceMatchedDataUpdate = 1 and exists(select * from #SourceSchema where PrimaryKeyOrder = 0) then 
				'when matched and ('+stuff((select ' or s.'+ quotename(columnName)+' is null and t.'+ quotename(columnName)+' is not null or s.'+ quotename(columnName)+' is not null and t.'+ quotename(columnName)+' is null or s.'+ quotename(columnName)+' <> t.'+ quotename(columnName) from #SourceSchema where PrimaryKeyOrder = 0 order by ColumnID for xml path(''), type).value('.','nvarchar(max)'), 1, 4,'')+') then 
update set '+stuff((select ', t.'+ quotename(columnName)+'= s.'+ quotename(columnName) from #SourceSchema where PrimaryKeyOrder = 0 order by ColumnID for xml path('')), 1, 1,'')
	else ''
	end+'
;'
	+ case when @HasIdentityColumn = 1  then '
set identity_insert ' + @FullObjectName + ' off;' else '' end
	exec z.usp_PrintString @SQL
end
