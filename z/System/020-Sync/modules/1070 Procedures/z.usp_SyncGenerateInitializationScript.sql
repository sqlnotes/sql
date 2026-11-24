create or alter procedure z.usp_SyncGenerateInitializationScript
(
	@FullTableName nvarchar(128),
	@DropTable nvarchar(max) = null output,
	@CreateSchema nvarchar(max) = null output,
	@CreateTable nvarchar(max) = null output,
	@CreateInterface nvarchar(max) = null output,
	@CreateTrigger nvarchar(max) = null output,
	@SyncMethod varchar(100) = 'RowVersion',
	@AlternatePrimaryKey varchar(3000) = null
)
as
begin
	set nocount, xact_abort on
	declare @TableName nvarchar(128) = object_name(object_id(@FullTableName)),
			@SchemaName nvarchar(128) = object_schema_name(object_id(@FullTableName)),
			@ObjectID int
	select @FullTableName = quotename(@SchemaName) + '.' + quotename(@TableName)
	select @ObjectID = object_id(@FullTableName)
	if @ObjectID is null
	begin
		raiserror('Could not find object %s.', 16, 1, @FullTableName)
		return
	end

	select @DropTable = 'declare @SQL nvarchar(max)
if exists (select * from sys.sql_expression_dependencies d inner join sys.sql_modules m on m.object_id = d.referencing_id where m.is_schema_bound = 1 and d.referenced_id = object_id('+quotename(@FullTableName, '''')+'))
	throw 50000, ''Remove schema-bound dependencies on the target table before initialization.'', 1;
if object_id('+quotename(@FullTableName, '''')+') is not null
begin
	select @SQL = (
			select ''alter table '' + object_schema_name(f.parent_object_id) + ''.'' + quotename(object_name(f.parent_object_id)) + '' drop constraint '' + quotename(f.name) + '';
''
			from sys.foreign_keys f
			where parent_object_id = object_id('+quotename(@FullTableName, '''')+')
				or referenced_object_id = object_id('+quotename(@FullTableName, '''')+')
			for xml path(''''), type
		).value(''.'', ''nvarchar(max)'')
	exec(@SQL)
	drop table '+@FullTableName+';
end
'
	select @CreateSchema = 'if schema_id(' + quotename(@SchemaName, '''')+') is null
begin
	exec(''create schema '+quotename(@SchemaName)+''');
end'
	create table #1 (ID int identity(1,1) primary key, Type nvarchar(50) not null,ObjectName nvarchar(512), Definition nvarchar(max),ParentObjectName nvarchar(512))
	insert into #1(Type, ParentObjectName, ObjectName, Definition)
		select	'Table',
				schema_name(t.schema_id)+'.'+t.name,
				schema_name(t.schema_id)+'.'+t.name,
				'begin transaction
if object_id(' + quotename(schema_name(t.schema_id)+'.'+t.name, '''') +') is null
begin
	create table ' + quotename(schema_name(t.schema_id)) + '.' + quotename(t.name) + '
	('
					+ stuff(
							(
								select
										',
		' + quotename(t.ColumnName)
										+	case
												when t.IsComputed = 1 then ' as ' + t.ComputedColumnDefinition
												else
													' ' + t.DataTypeByUserType + case when t.IsNullable = 1 then ' null' else ' not null' end
													+case when t.IsIdentity = 1 then ' identity(1,1) ' else '' end
											end
								from z.fn_SyncGetTableStructure(quotename(schema_name(t.schema_id)) + '.' + quotename(t.name)) t
								order by t.ColumnID
								for xml path(''), type
							).value('.', 'nvarchar(max)') , 1, 1, '')+'
	)
'
			from sys.tables t
				left join sys.data_spaces d on d.data_space_id = t.lob_data_space_id
				left join sys.indexes i on i.index_id in(0,1) and i.object_id = t.object_id
				left join sys.data_spaces d1 on d1.data_space_id = i.data_space_id
			where t.object_id = @ObjectID
			order by 3
		insert into #1(Type, ParentObjectName, ObjectName, Definition)
			select	'PrimaryKey',
				schema_name(t.schema_id)+'.'+t.name,
				i.ExpectedIndexName,
				'	alter table ' + quotename(schema_name(t.schema_id))+'.'+ quotename(t.name)+ ' add constraint ' + quotename(i.ExpectedIndexName) + ' primary key ' + lower(i.IndexType) collate database_default  +	' (' + i.IndexColumnDefinition + ')'
		+ case when i.IncludedColumns is not null then ' include(' + i.IncludedColumns + ')'  else '' end
		+ case when i.FilterDefinition is not null then ' where ' + i.FilterDefinition else '' end
		+ '	with(pad_index = ' + case when i.IsPadded = 1 then 'on' else 'off' end + case when i.IgnoreDuplicatedKey = 1 then ',ignore_dup_key=on' else '' end + isnull(',data_compression=' + i.Compression , '')+')'
		+ ';
'
			from sys.tables t
				inner join z.v_Indexes i on i.ObjectID = t.object_id
			where i.IsPrimaryKey = 1
				and t.object_id = @ObjectID
			order by 3
		insert into #1(Type, ParentObjectName, ObjectName, Definition)
			select	'UniqueKey',
				schema_name(t.schema_id)+'.'+t.name,
				i.ExpectedIndexName,
				'	alter table ' + quotename(schema_name(t.schema_id))+'.'+ quotename(t.name)+ ' add constraint ' + quotename(i.ExpectedIndexName) + ' unique ' + lower(i.IndexType) collate database_default  +	' (' + i.IndexColumnDefinition + ')'
		+ case when i.IncludedColumns is not null then ' include(' + i.IncludedColumns + ')'  else '' end
		+ case when i.FilterDefinition is not null then ' where ' + i.FilterDefinition else '' end
		+ '	with(pad_index = ' + case when i.IsPadded = 1 then 'on' else 'off' end + case when i.IgnoreDuplicatedKey = 1 then ',ignore_dup_key=on' else '' end + isnull(',data_compression=' + i.Compression , '')+')'
		+ ';
'
			from sys.tables t
				inner join z.v_Indexes i on i.ObjectID = t.object_id
			where i.IsPrimaryKey = 0 and i.IsUniqueConstraint = 1
				and t.object_id = @ObjectID
			order by 3

		insert into #1(Type, ParentObjectName, ObjectName, Definition)
			select	'UniqueIndex',
				schema_name(t.schema_id)+'.'+t.name,
				i.ExpectedIndexName,
				'	create unique ' + lower(i.IndexType)  collate database_default +' index ' + quotename(i.ExpectedIndexName) + ' on ' + quotename(schema_name(t.schema_id))+'.'+ quotename(t.name) + ' (' + i.IndexColumnDefinition + ')'
		+ case when i.IncludedColumns is not null then ' include(' + i.IncludedColumns + ')'  else '' end
		+ case when i.FilterDefinition is not null then ' where ' + i.FilterDefinition else '' end
		+ 'with(pad_index = ' + case when i.IsPadded = 1 then 'on' else 'off' end + case when i.IgnoreDuplicatedKey = 1 then ',ignore_dup_key=on' else '' end + isnull(',data_compression=' + i.Compression , '')+')'
		+ ';
'
			from sys.tables t
				inner join z.v_Indexes i on i.ObjectID = t.object_id
			where i.IsPrimaryKey = 0 and i.IsUniqueConstraint = 0 and i.IsUnique = 1
				and t.object_id = @ObjectID
			order by 3
		insert into #1(Type, ParentObjectName, ObjectName, Definition)
			select	'Index',
				schema_name(t.schema_id)+'.'+t.name,
				i.ExpectedIndexName,
				'	create ' + case when lower(i.IndexType) <> 'xml' then lower(i.IndexType) else 'primary xml' end collate database_default +' index ' + quotename(i.ExpectedIndexName) + ' on ' + quotename(schema_name(t.schema_id))+'.'+ quotename(t.name) + ' (' + case when i.IndexType like '%columnstore%' then i.IncludedColumns else i.IndexColumnDefinition end + ')'
		+ case when i.IncludedColumns is not null  and i.IndexType not like '%columnstore' then ' include(' + i.IncludedColumns + ')'  else '' end
		+ case when i.FilterDefinition is not null then ' where ' + i.FilterDefinition else '' end
		+ case when lower(i.IndexType) <> 'xml' then ' with(pad_index = ' + case when i.IsPadded = 1 then 'on' else 'off' end + case when i.IgnoreDuplicatedKey = 1 then ',ignore_dup_key=on' else '' end + isnull(',data_compression=' + i.Compression , '')+')'
		else '' end+ ';
'
			from sys.tables t
				inner join z.v_Indexes i on i.ObjectID = t.object_id
			where i.IsPrimaryKey = 0 and i.IsUniqueConstraint = 0 and i.IsUnique = 0 and i.IndexType not like '%columnstore%'
				and t.object_id = @ObjectID
			order by 3
		insert into #1(Type, ParentObjectName, ObjectName, Definition)
			select	'ColumnStore',
				schema_name(t.schema_id)+'.'+t.name,
				i.ExpectedIndexName,
				'	create ' + lower(i.IndexType)  collate database_default +' index ' + quotename(i.ExpectedIndexName) + ' on ' + quotename(schema_name(t.schema_id))+'.'+ quotename(t.name) + ' (' + case when i.IndexType like '%columnstore%' then i.IncludedColumns else i.IndexColumnDefinition end + ')'
		+ case when i.IncludedColumns is not null  and i.IndexType not like '%columnstore' then ' include(' + i.IncludedColumns + ')'  else '' end
		+ case when i.FilterDefinition is not null then ' where ' + i.FilterDefinition else '' end
		+ ';
'
			from sys.tables t
				inner join z.v_Indexes i on i.ObjectID = t.object_id
			where i.IsPrimaryKey = 0 and i.IsUniqueConstraint = 0 and i.IsUnique = 0 and i.IndexType like '%columnstore%'
				and t.object_id = @ObjectID
			order by 3
		insert into #1(Type, ParentObjectName, ObjectName, Definition)
			select	'DefaultConstraint',
			schema_name(t.schema_id)+'.'+t.name,
				schema_name(t.schema_id)+'.'+d.ExpectedDefaultName,
				'	alter table ' + quotename(schema_name(t.schema_id))+'.'+quotename(t.name) + '  add constraint ' + quotename(d.ExpectedDefaultName)+ ' default ' + d.Definition +' for ' + quotename(d.ParentColumnName) + ';
'
			from sys.tables t
				inner join z.v_DefaultConstraints d on d.ParentObjectID = t.object_id
			where t.object_id = @ObjectID
			order by 3
		insert into #1(Type, ParentObjectName, ObjectName, Definition)
			select	'CheckConstraint',
				schema_name(t.schema_id)+'.'+t.name,
				schema_name(t.schema_id)+'.'+c.CheckConstraintName,
				'	alter table ' + quotename(schema_name(t.schema_id)) + '.' + quotename(t.name) + case when c.IsDisabled = 1 then ' with nocheck' else ' with check' end + ' add constraint ' + quotename(c.CheckConstraintName) + ' check ' + c.Definition + ';
'
			from sys.tables t
				inner join z.v_CheckConstraints c on c.ParentObjectID = t.object_id
			where t.object_id = @ObjectID
			order by 3

	;with x0 as
	(
		select *,
		case Type
			when 'Table ' then 1
			when 'PrimaryKey' then 2
			when 'UniqueKey' then 3
			when 'UniqueIndex' then 4
			when 'Index' then 5
			when 'ColumnStore' then 6
			when 'CheckConstraint' then 7
			when 'DefaultConstraint' then 8
		end Ordinal
		from #1
	)
	select @CreateTable =
	(
		select Definition +''
		from x0
		for xml path(''), type
	).value('.', 'nvarchar(max)') + 'end
commit'
	exec z.usp_SyncCreateTargetForJDBCBulkCopy @TargetTable = @FullTableName, @Execute = 0, @PrintCode = 0, @Interface = @CreateInterface output, @Trigger = @CreateTrigger output, @AlternatePrimaryKey = @AlternatePrimaryKey, @SyncMethod = @SyncMethod
end


go
