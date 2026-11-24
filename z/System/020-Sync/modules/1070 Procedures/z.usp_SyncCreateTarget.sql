create or alter procedure z.usp_SyncCreateTarget
(
	@TargetTable sysname,
	@ServerName nvarchar(128) = null,
	@DatabaseName nvarchar(128) = null,
	@Execute bit = 1,
	@PrintCode bit =0,
	@Interface nvarchar(max) = null output,
	@Trigger nvarchar(max) = null output
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

	create table #TargetDefinition(ObjectID int null,SchemaName nvarchar(128) null,ObjectName nvarchar(128) null,ColumnName nvarchar(128) null,ColumnID int null,PrimaryKeyOrder int null,DataLength smallint not null,DataType nvarchar(171) null,IsNullable bit null,ReadOnly bit null,CollationName sysname null,IsIdentity bit null,IsComputed bit null,ComputedColumnDefinition nvarchar(max) null,IsTimestamp bit null,SystemType nvarchar(128) null,UserType nvarchar(128) null,MaxLength smallint not null,DataTypeByUserType nvarchar(171) null)

	insert into #TargetDefinition
		exec z.usp_SyncGetTableSchema @ServerName, @DatabaseName, @FullTableName
	select @SQL = 'create or alter view '+@InterfaceName+' as select top 0 ' + (select 'cast(null as '+DataType+') as '+quotename(ColumnName)+',' from #TargetDefinition order by ColumnID for xml path(''), type).value('.', 'varchar(max)') + 'cast(0 as bit) as ___IsDeleted___'
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
	set nocount on;
	'+isnull((select 'set identity_insert '+@FullTableName + ' on ' from #TargetDefinition where IsIdentity = 1), '')+'
	merge '+@FullTableName+' t
	using inserted s on '+stuff((select ' and s.'+quotename(ColumnName)+' = t.'+quotename(ColumnName) from #TargetDefinition where PrimaryKeyOrder > 0 order by PrimaryKeyOrder for xml path(''), type).value('.', 'varchar(max)'), 1, 5, '')+'
	when not matched and isnull(s.___IsDeleted___, 0) = 0 then
		insert (' +stuff((select ','+quotename(ColumnName) from #TargetDefinition where IsComputed <> 1 and IsTimestamp <> 1 order by ColumnID for xml path(''), type).value('.', 'varchar(max)'), 1, 1, '')+ ')
			values (' +stuff((select ',s.'+quotename(ColumnName) from #TargetDefinition where IsComputed <> 1 and IsTimestamp <> 1 order by ColumnID for xml path(''), type).value('.', 'varchar(max)'), 1, 1, '')+ ')
	when matched and isnull(s.___IsDeleted___, 0) = 0 and ('+stuff((select ' or s.'+quotename(ColumnName)+' is null and t.'+quotename(ColumnName)+' is not null or s.'+quotename(ColumnName)+' is not null and t.'+quotename(ColumnName)+' is null or '+case when DataType in ('xml', 'text','ntext', 'image') then 'cast(s.'+quotename(ColumnName)+' as varbinary(max)) <> cast(t.'+quotename(ColumnName)+' as varbinary(max))' else 's.'+quotename(ColumnName)+' <> t.'+quotename(ColumnName) end from #TargetDefinition where ReadOnly = 0 and PrimaryKeyOrder = 0 order by PrimaryKeyOrder for xml path(''), type).value('.', 'varchar(max)'), 1, 3, '')+') then
		update set '+stuff((select ',t.'+quotename(ColumnName)+' = s.'+quotename(ColumnName) from #TargetDefinition where PrimaryKeyOrder = 0 and ReadOnly = 0  order by PrimaryKeyOrder for xml path(''), type).value('.', 'varchar(max)'), 1, 1, '')+'
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
	'+isnull((select 'set identity_insert '+@FullTableName + ' on ' from #TargetDefinition where IsIdentity = 1), '')+'
	merge '+@FullTableName+' t
	using inserted s on '+stuff((select ' and s.'+quotename(ColumnName)+' = t.'+quotename(ColumnName) from #TargetDefinition where PrimaryKeyOrder > 0 order by PrimaryKeyOrder for xml path(''), type).value('.', 'varchar(max)'), 1, 5, '')+'
	when not matched and isnull(s.___IsDeleted___, 0) = 0 then
		insert (' +stuff((select ','+quotename(ColumnName) from #TargetDefinition where IsComputed <> 1 and IsTimestamp <> 1 order by ColumnID for xml path(''), type).value('.', 'varchar(max)'), 1, 1, '')+ ')
			values (' +stuff((select ',s.'+quotename(ColumnName) from #TargetDefinition where IsComputed <> 1 and IsTimestamp <> 1 order by ColumnID for xml path(''), type).value('.', 'varchar(max)'), 1, 1, '')+ ')
	when matched and isnull(s.___IsDeleted___, 0) = 1 then
		delete
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
