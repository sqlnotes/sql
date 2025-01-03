create or alter procedure z.usp_GetQueryResultToSQL
(
	@Query nvarchar(max),
	@SQL nvarchar(max) output
)
as
begin
	set nocount on
	declare @ResultDefinition table (is_hidden bit, column_ordinal int, name nvarchar(128), is_nullable bit, system_type_id int, system_type_name nvarchar(256), max_length smallint, precision tinyint, scale tinyint, collation_name nvarchar(128), user_type_id int, user_type_database nvarchar(128), user_type_schema nvarchar(128), user_type_name nvarchar(128), assembly_qualified_type_name nvarchar(4000), xml_collection_id int, xml_collection_database nvarchar(128), xml_collection_schema nvarchar(128), xml_collection_name nvarchar(128), is_xml_document bit, is_case_sensitive bit, is_fixed_length_clr_type bit, source_server nvarchar(128), source_database nvarchar(128), source_schema nvarchar(128), source_table nvarchar(128), source_column nvarchar(128), is_identity_column bit, is_part_of_unique_key bit, is_updateable bit, is_computed_column bit, is_sparse_column_set bit, ordinal_in_order_by_list smallint, order_by_list_length smallint, order_by_is_descending smallint, tds_type_id int, tds_length int, tds_collation_id int, tds_collation_sort_id tinyint)
	insert into @ResultDefinition
		exec sp_describe_first_result_set @Query
	;with x0 as
	(
		select

			c.name ColumnName, cast(c.column_ordinal as int) ColumnID,
			c.max_length DataLength, isnull(type_name(c.system_type_id), type_name(c.user_type_id)) BaseType,
			case when isnull(type_name(c.system_type_id), type_name(c.user_type_id)) = 'timestamp' then 'binary(8)' else isnull(type_name(c.system_type_id), type_name(c.user_type_id)) end +
			case 
				when isnull(type_name(c.system_type_id), type_name(c.user_type_id)) in ('binary', 'char', 'nchar') then '('+cast(c.max_length as varchar(20))+')'
				when isnull(type_name(c.system_type_id), type_name(c.user_type_id)) in ('nchar') then '('+cast(c.max_length/2 as varchar(20))+')'
				when isnull(type_name(c.system_type_id), type_name(c.user_type_id)) in ('datetime2', 'datetimeoffset', 'time') then '('+cast(c.scale as varchar(20))+')'
				when isnull(type_name(c.system_type_id), type_name(c.user_type_id)) in ('decimal', 'numeric') then '('+cast(c.precision as varchar(20))+','+cast(c.scale as varchar(20))+')'
				when isnull(type_name(c.system_type_id), type_name(c.user_type_id)) in ('varchar') then '('+case when c.max_length = -1 then 'max' else cast(c.max_length as varchar(20)) end+')'
				when isnull(type_name(c.system_type_id), type_name(c.user_type_id)) in ('nvarchar') then '('+case when c.max_length = -1 then 'max' else cast(c.max_length/2 as varchar(20)) end+')'
				when isnull(type_name(c.system_type_id), type_name(c.user_type_id)) in ('varbinary') then '('+case when c.max_length = -1 then 'max' else cast(c.max_length as varchar(20)) end+')'
				else ''
			end DataType,
			cast(c.is_nullable as bit) IsNullable,
			c.collation_name as CollationName,
			cast(case when isnull(type_name(c.system_type_id), type_name(c.user_type_id)) = 'timestamp' then 1 else 0 end as bit) IsTimestamp,
			type_name(c.system_type_id) SystemType,
			type_name(c.user_type_id) UserType,
			c.max_length MaxLength
		from @ResultDefinition c
	)
	select @SQL = cast('
	declare @RecordExists bit = 1
	create table #t(' as nvarchar(max)) +stuff((select ',' + quotename(ColumnName) + ' ' + DataType
		from x0
		order by ColumnID
		for xml path(''), type).value('.', 'nvarchar(max)'), 1, 1, '') +')
	insert into #t
		exec(@Query)
	if not exists(select * from #t)
	begin
		select @RecordExists = 0
		insert into #t
			values('+stuff((select ',null'
		from x0
		order by ColumnID
		for xml path(''), type).value('.', 'nvarchar(max)'), 1, 1, '')+')
	end
	create table #Data(ID int identity(1,1) primary key, Data nvarchar(max))
	insert into #Data(Data)
		exec(''' + replace('select  ''('''+stuff((
										select '+'',''+'+
											
													case 
														when BaseType in ('image', 'binary', 'varbinary', 'timestamp'/*, 'Hierarchyid'*/) then 'case when '+quotename(ColumnName)+' is null then ''null'' else convert(varchar(max),cast('+quotename(ColumnName)+' as varbinary(max)), 1) end'														when BaseType in ('tinyint', 'smallint', 'int', 'real', 'float', 'bit', 'decimal', 'numeric', 'bigint', 'smallmoney', 'money') then 'case when '+quotename(ColumnName)+' is null then ''null'' else cast('+quotename(ColumnName)+' as varchar(100)) end'
														when BaseType in ('date', 'time', 'datetime2', 'datetimeoffset', 'smalldatetime', 'datetime') then  'case when '+quotename(ColumnName)+' is null then ''null'' else ''N''''''+replace(convert(nvarchar(max) , '+quotename(ColumnName)+', 120), '''''''', '''''''''''')+'''''''' end'
														else 'case when '+quotename(ColumnName)+' is null then ''null'' else ''N''''''+replace(convert(nvarchar(max) , '+quotename(ColumnName)+'), '''''''', '''''''''''')+'''''''' end'
													end

		from x0
		order by ColumnID 
										asc
		for xml path(''), type
										).value('.', 'nvarchar(max)'),1,4,'') 
									+ '+'')''
from #t', '''','''''')+''')
	if @RecordExists = 1
	begin
		select @SQL = cast(''select '+stuff((select ',cast('+quotename(ColumnName) +' as '+DataType+') as '+quotename(ColumnName)
		from x0
		order by ColumnID asc
		for xml path(''), type).value('.', 'varchar(max)'),1,1,'') + ''' as nvarchar(max)) + ''
from (
		values(''+stuff((select ''
			,''+Data  from #Data order by ID for xml path(''''), type).value(''.'', ''varchar(max)''),1,7,'''')+''
	) v('+stuff((select ','+quotename(ColumnName)
		from x0
		order by ColumnID asc
		for xml path(''), type).value('.', 'varchar(max)'),1,1,'') + ')''
	end
	else
	begin
		select @SQL = cast(''select top 0 '+stuff((select ',cast('+quotename(ColumnName) +' as '+DataType+') as '+quotename(ColumnName)
		from x0
		order by ColumnID asc
		for xml path(''), type).value('.', 'varchar(max)'),1,1,'') + ''' as nvarchar(max)) + ''
		from (
				values(''+stuff((select ''
					,''+Data  from #Data order by ID for xml path(''''), type).value(''.'', ''varchar(max)''),1,9,'''')+''
			) v('+stuff((select ','+quotename(ColumnName)
		from x0
		order by ColumnID asc
		for xml path(''), type).value('.', 'varchar(max)'),1,1,'') + ')''
	end
	'
	--select @SQL	
	exec sp_executesql @SQL, N'@Query nvarchar(max), @SQL nvarchar(max) output', @Query, @SQL output
end
go