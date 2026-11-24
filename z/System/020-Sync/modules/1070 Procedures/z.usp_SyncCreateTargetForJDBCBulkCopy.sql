create or alter procedure z.usp_SyncCreateTargetForJDBCBulkCopy
(
	@TargetTable sysname,
	@ServerName nvarchar(128) = null,
	@DatabaseName nvarchar(128) = null,
	@Execute bit = 1,
	@PrintCode bit =0,
	@Interface nvarchar(max) = null output,
	@Trigger nvarchar(max) = null output,
	@SyncMethod varchar(100) = 'RowVersion',
	@AlternatePrimaryKey varchar(3000) = null
)
as
begin
	set nocount, xact_abort on

	declare @SQL nvarchar(max), @SchemaName sysname, @TableName sysname, @FullTableName nvarchar(255)
	declare @InterfaceName sysname, @TriggerName sysname
	select @SQL = 'select @Output1 = object_schema_name(object_id('''+@TargetTable+''')), @Output2 = object_name(object_id('''+@TargetTable+'''))'
	exec z.usp_SyncExecuteSQLWithOutput @ServerName, @DatabaseName, @SQL, @SchemaName output, @TableName output

	select	@FullTableName = quotename(@SchemaName) + '.' + quotename(@TableName),
			@InterfaceName = quotename(@SchemaName) + '.' + quotename(@TableName + '_Interface'),
			@TriggerName = quotename(@SchemaName) + '.' + quotename('TRI_'+@TableName+'_Interface')

	create table #TargetDefinition(ObjectID int null,SchemaName nvarchar(128) null,ObjectName nvarchar(128) null,ColumnName nvarchar(128) null,ColumnID int null,PrimaryKeyOrder int null,DataLength smallint not null,DataType nvarchar(171) null,IsNullable bit null,ReadOnly bit null,CollationName sysname null,IsIdentity bit null,IsComputed bit null,ComputedColumnDefinition nvarchar(max) null,IsTimestamp bit null,SystemType nvarchar(128) null,UserType nvarchar(128) null,MaxLength smallint not null,DataTypeByUserType nvarchar(171) null, AlternatePrimaryKeyOrder int not null default(0))

	insert into #TargetDefinition(ObjectID,SchemaName,ObjectName,ColumnName,ColumnID,PrimaryKeyOrder,DataLength,DataType,IsNullable,ReadOnly,CollationName,IsIdentity,IsComputed,ComputedColumnDefinition,IsTimestamp,SystemType,UserType,MaxLength,DataTypeByUserType)
		exec z.usp_SyncGetTableSchema @ServerName, @DatabaseName, @FullTableName

	if @AlternatePrimaryKey is not null
	begin
		;with s as
		(
			select ltrim(rtrim(a.value)) ColumnName, row_number() over(order by id) AlternatePrimaryKeyOrder
			from(
				select a.value, 1 as id
				from  string_split(@AlternatePrimaryKey, ',') a
				) a
		)
		update t
			set t.AlternatePrimaryKeyOrder = s.AlternatePrimaryKeyOrder
		from #TargetDefinition t
			inner join s on s.ColumnName = t.ColumnName
		if @@rowcount = 0
		begin
			raiserror('Alternate Primary key is incorrect', 16, 1)
			return
		end
	end

	select @SQL = 'create or alter view '+@InterfaceName+' as select '
		+ (
			select 'cast('+quotename(ColumnName)+' as '+case when (DataType like 'datetime%' or DataType like 'time%') and DataType not in('timestamp', 'rowversion') then 'varchar(100)' else DataType end+') as '+quotename(ColumnName)+','
			from #TargetDefinition
			order by ColumnID for xml path(''), type
		).value('.', 'varchar(max)') + 'cast(0 as bit) as ___IsDeleted___ from ' + @FullTableName
	if @Execute = 1
		exec z.usp_SyncExecuteSQL @ServerName, @DatabaseName, @SQL
	if @PrintCode = 1
		exec z.usp_PrintString @SQL
	select @Interface = @SQL

	if exists(select * from #TargetDefinition where ReadOnly = 0 and PrimaryKeyOrder = 0)
	begin
		select @SQL = 'create or alter trigger ' + @TriggerName + ' on ' + @InterfaceName +'
instead of insert
as
begin
	if @@rowcount = 0
		return
	set nocount on;'
+'
	'+isnull((select 'set identity_insert '+@FullTableName + ' on ' from #TargetDefinition where IsIdentity = 1), '')+'
	merge '+@FullTableName+' t
	using (select * from inserted s  ) s on '+stuff((select ' and '+case when (DataType like 'datetime%' or DataType like 'time%') and DataType not in('timestamp', 'rowversion') then 'convert('+DataType+',s.'+quotename(ColumnName)+', 121)' else 's.'+quotename(ColumnName) end+' = t.'+quotename(ColumnName) from #TargetDefinition where PrimaryKeyOrder > 0 order by PrimaryKeyOrder for xml path(''), type).value('.', 'varchar(max)'), 1, 5, '')+'
	when not matched then
		insert (' +stuff((select ','+quotename(ColumnName) from #TargetDefinition where IsComputed <> 1 and IsTimestamp <> 1 order by ColumnID for xml path(''), type).value('.', 'varchar(max)'), 1, 1, '')+ ')
			values (' +stuff((
								select case when (DataType like 'datetime%' or DataType like 'time%') and DataType not in('timestamp', 'rowversion') then ',convert('+DataType+', s.'+quotename(ColumnName)+', 121)' else ',s.'+quotename(ColumnName) end
								from #TargetDefinition
								where IsComputed <> 1
									and IsTimestamp <> 1
								order by ColumnID for xml path(''), type
							).value('.', 'varchar(max)'), 1, 1, '')+ ')
	when matched and (isnull(s.___IsDeleted___, 0) = 0) and ('+stuff((
																	select ' or s.'+quotename(ColumnName)+' is null and t.'+quotename(ColumnName)+' is not null or s.'+quotename(ColumnName)+' is not null and t.'+quotename(ColumnName)+' is null or '
																	+	case
																			when DataType in ('xml', 'text','ntext', 'image') then 'cast(s.'+quotename(ColumnName)+' as varbinary(max)) <> cast(t.'+quotename(ColumnName)+' as varbinary(max))'
																			when (DataType like 'datetime%' or DataType like 'time%') and DataType not in('timestamp', 'rowversion') then 'convert('+DataType+', s.'+quotename(ColumnName)+', 121) <> t.'+quotename(ColumnName)
																			else 's.'+quotename(ColumnName)+' <> t.'+quotename(ColumnName)
																		end
																	from #TargetDefinition
																	where ReadOnly = 0
																		and PrimaryKeyOrder = 0
																	order by PrimaryKeyOrder for xml path(''), type
																).value('.', 'varchar(max)'), 1, 3, '')+') then
		update set '+stuff((
							select ',t.'+quotename(ColumnName)+ case when (DataType like 'datetime%' or DataType like 'time%') and DataType not in('timestamp', 'rowversion') then ' = convert('+DataType+', s.'+quotename(ColumnName)+', 121)' else ' = s.'+quotename(ColumnName)  end
							from #TargetDefinition
							where PrimaryKeyOrder = 0
								and ReadOnly = 0
							order by PrimaryKeyOrder for xml path(''), type
						).value('.', 'varchar(max)'), 1, 1, '')+'
	when matched and isnull(s.___IsDeleted___, 0) = 1 then
		delete
	;
	'+isnull((select 'set identity_insert '+@FullTableName + ' off ' from #TargetDefinition where IsIdentity = 1), '')+'
end
'
	end
	else
	begin
			select @SQL = 'create or alter trigger ' + @TriggerName + ' on ' + @InterfaceName +'
instead of insert
as
begin
	if @@rowcount = 0
		return
	set nocount on;
	'

		+ '
	'+isnull((select 'set identity_insert '+@FullTableName + ' on ' from #TargetDefinition where IsIdentity = 1), '')+'
	merge '+@FullTableName+' t
	using (select * from inserted s  ) s on '+stuff((select ' and '+case when (DataType like 'datetime%' or DataType like 'time%') and DataType not in('timestamp', 'rowversion') then 'convert('+DataType+',s.'+quotename(ColumnName)+', 121)' else 's.'+quotename(ColumnName) end +' = t.'+quotename(ColumnName) from #TargetDefinition where PrimaryKeyOrder > 0 order by PrimaryKeyOrder for xml path(''), type).value('.', 'varchar(max)'), 1, 5, '')+'
	when not matched and isnull(s.___IsDeleted___, 0) = 0 then
		insert (' +stuff((select ','+quotename(ColumnName) from #TargetDefinition where IsComputed <> 1 and IsTimestamp <> 1 order by ColumnID for xml path(''), type).value('.', 'varchar(max)'), 1, 1, '')+ ')
			values (' +stuff((
								select case when (DataType like 'datetime%' or DataType like 'time%') and DataType not in('timestamp', 'rowversion') then ',convert('+DataType+', s.'+quotename(ColumnName)+', 121)' else ',s.'+quotename(ColumnName) end
								from #TargetDefinition
								where IsComputed <> 1
									and IsTimestamp <> 1
								order by ColumnID for xml path(''), type
							).value('.', 'varchar(max)'), 1, 1, '')+ ')
	;
	'+isnull((select 'set identity_insert '+@FullTableName + ' off ' from #TargetDefinition where IsIdentity = 1), '')+'
end
'

	end
	select @Trigger = @SQL
	if @Execute = 1
		exec z.usp_SyncExecuteSQL @ServerName, @DatabaseName, @SQL
	if @PrintCode = 1
		exec z.usp_PrintString @SQL
end

go
