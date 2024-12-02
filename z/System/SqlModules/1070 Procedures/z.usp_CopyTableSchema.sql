create or alter procedure z.usp_CopyTableSchema
(
	@FullSourceTableName nvarchar(256),
	@FullTargetTableName nvarchar(256),
	@FileGroupOrPartitionScheme nvarchar(128) = null,
	@DropTargetTableIfExists bit = 1,
	@CopyIdentity bit = 0,
	@CopyTableSchema bit = 1,
	@CopyIndexes bit = 1,
	@CopyXMLIndexes bit = 0,
	@CopyDefault bit = 1,
	@ScriptAfterTableCreation nvarchar(max) = null,
	@PrintCode bit = 0,
	@DataCompression varchar(20) = null
)
as
begin
	set nocount, xact_abort on
	declare @SourceTableName nvarchar(128) = object_name(object_id(@FullSourceTableName)), 
			@SourceSchemaName nvarchar(128) = object_schema_name(object_id(@FullSourceTableName)),
			@TargetTableName nvarchar(128) = parsename(@FullTargetTableName, 1),
			@TargetSchemaName nvarchar(128) = parsename(@FullTargetTableName, 2),
			@ObjectID int, @SQL nvarchar(max), @PartitionKey nvarchar(128),
			@XMLPrimaryIndexName nvarchar(128) = cast(newid() as nvarchar(128))
	select @FullSourceTableName = quotename(@SourceSchemaName) + '.' + quotename(@SourceTableName)
	select @FullTargetTableName  = quotename(@TargetSchemaName) + '.' + quotename(@TargetTableName)
	select @ObjectID = object_id(@FullSourceTableName)
	if @ObjectID is null
	begin
		raiserror('Could not find object %s.', 16, 1, @FullSourceTableName)
		return
	end
	if object_id(@FullTargetTableName) is not null and @DropTargetTableIfExists = 1
	begin
		select @SQL = 'drop table ' + @FullTargetTableName
		exec(@SQL)
	end

	select top (iif(object_id(@FullTargetTableName) is null, 9999999, 0)) 
		* into #TableStructure 
	from z.v_Objects
	where ObjectID = @ObjectID
	
	select top (iif(@CopyIndexes = 1, 9999999, 0)) 
		* into #IndexStructure 
	from z.v_Indexes
	where ObjectID = @ObjectID
	
	select top (iif(@CopyDefault = 1, 9999999, 0)) 
		* into #DefaultStructure 
	from z.v_DefaultConstraints
	where ParentObjectID = @ObjectID
		
	if @FileGroupOrPartitionScheme is null
	begin
		select @FileGroupOrPartitionScheme = ds.name
		from sys.partitions p
			inner join sys.allocation_units au on p.partition_id = au.container_id
			inner join sys.data_spaces ds on ds.data_space_id = au.data_space_id
		where p.object_id = @ObjectID
	end

	if @FileGroupOrPartitionScheme like '%(%'
	begin
		select @PartitionKey = ltrim(rtrim(replace(substring(@FileGroupOrPartitionScheme, charindex('(', @FileGroupOrPartitionScheme) + 1, 200), ')', '')))
	end
		
	create table #1 (ID int identity(1,1) primary key, Type nvarchar(50) not null,Definition nvarchar(max)) 
	insert into #1(Type, Definition)
		select	'Table',
				'create table ' + @FullTargetTableName + '
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
													+case when t.IsIdentity = 1 and @CopyIdentity = 1 then ' identity(1,1) ' else '' end
											end
								from #TableStructure t
								order by t.ColumnID
								for xml path(''), type
							).value('.', 'nvarchar(max)') , 1, 1, '')+'
	) on ' + @FileGroupOrPartitionScheme + ';'
		if @ScriptAfterTableCreation is not null
		begin
			insert into #1 (Type, Definition)
				values('Table1', @ScriptAfterTableCreation)
		end
			
		insert into #1(Type, Definition)
			select	'PrimaryKey',
				'alter table ' + @FullTargetTableName + ' add constraint ' + quotename(cast(newid() as nvarchar(max))) + ' primary key ' + lower(i.IndexType) collate database_default  
				+' (' + i.IndexColumnDefinition + case when @PartitionKey is not null and not exists(select * from string_split(i.IndexColumnDefinition, ',') a where rtrim(ltrim(replace(replace(replace(replace(a.value, '[', ''), ']', ''), 'asc', ''), 'desc', ''))) = @PartitionKey) then ',' + @PartitionKey else '' end + ')'
		+ case when i.IncludedColumns is not null then ' include(' + i.IncludedColumns + ')'  else '' end
		+ case when i.FilterDefinition is not null then ' where ' + i.FilterDefinition else '' end 
		+ ' with('
				+ 'pad_index = ' + iif(i.IsPadded = 1, 'on', 'off')
				+ ', ignore_dup_key = ' + + iif(i.IgnoreDuplicatedKey = 1, 'on', 'off')
				+ ', allow_row_locks = ' + + iif(i.AllowRowLocks = 1, 'on', 'off')
				+ ', allow_page_locks = ' + + iif(i.AllowPageLocks = 1, 'on', 'off')
				+ ', optimize_for_sequential_key = ' + + iif(i.OptimizeForSequentialKey = 1, 'on', 'off')
				+ isnull(',data_compression=' + isnull(@DataCompression, i.Compression), '')
		+') on ' + @FileGroupOrPartitionScheme + ';'
			from #IndexStructure i
			where i.IsPrimaryKey = 1
				
		insert into #1(Type, Definition)
			select	'UniqueKey',
				'alter table ' + @FullTargetTableName+ ' add constraint ' + quotename(cast(newid() as nvarchar(max))) + ' unique ' + lower(i.IndexType) collate database_default  
				+' (' + i.IndexColumnDefinition + case when @PartitionKey is not null and not exists(select * from string_split(i.IndexColumnDefinition, ',') a where rtrim(ltrim(replace(replace(replace(replace(a.value, '[', ''), ']', ''), 'asc', ''), 'desc', ''))) = @PartitionKey) then ',' + @PartitionKey else '' end + ')'
		+ case when i.IncludedColumns is not null then ' include(' + i.IncludedColumns + ')'  else '' end
		+ case when i.FilterDefinition is not null then ' where ' + i.FilterDefinition else '' end 
		+ ' with('
				+ 'pad_index = ' + iif(i.IsPadded = 1, 'on', 'off')
				+ ', ignore_dup_key = ' + + iif(i.IgnoreDuplicatedKey = 1, 'on', 'off')
				+ ', allow_row_locks = ' + + iif(i.AllowRowLocks = 1, 'on', 'off')
				+ ', allow_page_locks = ' + + iif(i.AllowPageLocks = 1, 'on', 'off')
				+ ', optimize_for_sequential_key = ' + + iif(i.OptimizeForSequentialKey = 1, 'on', 'off')
				+ isnull(',data_compression=' + isnull(@DataCompression, i.Compression), '')
		+') on ' + @FileGroupOrPartitionScheme + ';'
			from #IndexStructure i
			where i.IsPrimaryKey = 0 and i.IsUniqueConstraint = 1

		insert into #1(Type, Definition)
			select	'UniqueIndex',
				'create unique ' + lower(i.IndexType)  collate database_default +' index ' + quotename(cast(newid() as nvarchar(max))) + ' on ' + @FullTargetTableName 
				+ ' (' + i.IndexColumnDefinition + case when @PartitionKey is not null and not exists(select * from string_split(i.IndexColumnDefinition, ',') a where rtrim(ltrim(replace(replace(replace(replace(a.value, '[', ''), ']', ''), 'asc', ''), 'desc', ''))) = @PartitionKey) then ',' + @PartitionKey else '' end + ')'
		+ case when i.IncludedColumns is not null then ' include(' + i.IncludedColumns + ')'  else '' end
		+ case when i.FilterDefinition is not null then ' where ' + i.FilterDefinition else '' end 
		+ ' with('
				+ 'pad_index = ' + iif(i.IsPadded = 1, 'on', 'off')
				+ ', ignore_dup_key = ' + + iif(i.IgnoreDuplicatedKey = 1, 'on', 'off')
				+ ', allow_row_locks = ' + + iif(i.AllowRowLocks = 1, 'on', 'off')
				+ ', allow_page_locks = ' + + iif(i.AllowPageLocks = 1, 'on', 'off')
				+ ', optimize_for_sequential_key = ' + + iif(i.OptimizeForSequentialKey = 1, 'on', 'off')
				+ isnull(',data_compression=' + isnull(@DataCompression, i.Compression), '')
		+') on ' + @FileGroupOrPartitionScheme + ';'
			from #IndexStructure i
			where i.IsPrimaryKey = 0 and i.IsUniqueConstraint = 0 and i.IsUnique = 1

		insert into #1(Type, Definition)
			select	'Index',
				'create ' + case when lower(i.IndexType) <> 'xml' then lower(i.IndexType) else 'primary xml' end collate database_default +' index ' + quotename(cast(newid() as nvarchar(max))) + ' on ' + @FullTargetTableName + ' (' + case when i.IndexType like '%columnstore%' then i.IncludedColumns else i.IndexColumnDefinition end + ')'
		+ case when i.IncludedColumns is not null  and i.IndexType not like '%columnstore' then ' include(' + i.IncludedColumns + ')'  else '' end
		+ case when i.FilterDefinition is not null then ' where ' + i.FilterDefinition else '' end 
		+ ' with('
				+ 'pad_index = ' + iif(i.IsPadded = 1, 'on', 'off')
				--+ ', ignore_dup_key = ' + + iif(i.IgnoreDuplicatedKey = 1, 'on', 'off')
				+ ', allow_row_locks = ' + + iif(i.AllowRowLocks = 1, 'on', 'off')
				+ ', allow_page_locks = ' + + iif(i.AllowPageLocks = 1, 'on', 'off')
				+ ', optimize_for_sequential_key = ' + + iif(i.OptimizeForSequentialKey = 1, 'on', 'off')
				+ isnull(',data_compression=' + isnull(@DataCompression, i.Compression), '')
		+') on ' + @FileGroupOrPartitionScheme + ';'
			from #IndexStructure i
			where i.IsPrimaryKey = 0 and i.IsUniqueConstraint = 0 and i.IsUnique = 0 and i.IndexType not like '%columnstore%'
				and i.IndexType not like '%xml%'

		insert into #1(Type, Definition)
			select	'ColumnStore',
				'create ' + lower(i.IndexType)  collate database_default +' index ' + quotename(cast(newid() as nvarchar(max))) + ' on ' + @FullTargetTableName + ' (' + case when i.IndexType like '%columnstore%' then i.IncludedColumns else i.IndexColumnDefinition end + ')'
			+ case when i.IncludedColumns is not null  and i.IndexType not like '%columnstore' then ' include(' + i.IncludedColumns + ')'  else '' end
			+ case when i.FilterDefinition is not null then ' where ' + i.FilterDefinition else '' end 
			+ ' on ' + @FileGroupOrPartitionScheme + ';'
			from #IndexStructure i
			where i.IsPrimaryKey = 0 and i.IsUniqueConstraint = 0 and i.IsUnique = 0 and i.IndexType like '%columnstore%'

		if @CopyXMLIndexes = 1
		begin
			insert into #1(Type, Definition)
				select	'XMLPrimary',
					'create primary xml index ' + quotename(cast(@XMLPrimaryIndexName as nvarchar(max))) + ' on ' + @FullTargetTableName + ' (' + i.IndexColumns + ')'
					+ ' with('
						+ 'pad_index = ' + iif(i.IsPadded = 1, 'on', 'off')
						--+ ', ignore_dup_key = ' + + iif(i.IgnoreDuplicatedKey = 1, 'on', 'off')
						+ ', allow_row_locks = ' + + iif(i.AllowRowLocks = 1, 'on', 'off')
						+ ', allow_page_locks = ' + + iif(i.AllowPageLocks = 1, 'on', 'off')
						+ ', optimize_for_sequential_key = ' + + iif(i.OptimizeForSequentialKey = 1, 'on', 'off')
						+ isnull(',data_compression=' + isnull(@DataCompression, i.Compression), '')
					+');'
				from #IndexStructure i
				where IndexType = 'PRIMARY_XML'
			insert into #1(Type, Definition)
				select	'XMLOther',
					'create xml index ' + quotename(cast(newid() as nvarchar(max))) + ' on ' + @FullTargetTableName + ' (' + i.IndexColumns + ')'
					+' using xml index ' + quotename(cast(@XMLPrimaryIndexName as nvarchar(max))) 
					+ ' for ' + case i.IndexType
									when 'SECONDARY_XML_PATH' then 'path'
									when 'SECONDARY_XML_VALUE' then 'value'
									when 'SECONDARY_XML_PROPERTY' then 'property'
								end
					+ ' with('
						+ 'pad_index = ' + iif(i.IsPadded = 1, 'on', 'off')
						--+ ', ignore_dup_key = ' + + iif(i.IgnoreDuplicatedKey = 1, 'on', 'off')
						+ ', allow_row_locks = ' + + iif(i.AllowRowLocks = 1, 'on', 'off')
						+ ', allow_page_locks = ' + + iif(i.AllowPageLocks = 1, 'on', 'off')
						+ ', optimize_for_sequential_key = ' + + iif(i.OptimizeForSequentialKey = 1, 'on', 'off')
						+ isnull(',data_compression=' + isnull(@DataCompression, i.Compression), '')
					+');'
				from #IndexStructure i
				where IndexType <> 'PRIMARY_XML'
					and IndexType like '%XML%'
		end
	
		insert into #1(Type, Definition)
			select	'DefaultConstraint',
				'alter table ' + @FullTargetTableName + '  add constraint ' + quotename(cast(newid() as nvarchar(max)))+ ' default ' + d.Definition +' for ' + quotename(d.ParentColumnName) + ';
'
			from #DefaultStructure d
	delete #1 where Definition is null
	if not exists(select * from #1)
		return
	declare c cursor local for
		select Definition
		from #1
		where Definition is not null
		order by case Type
			when 'Table' then 10
			when 'Table1' then 12
			when 'PrimaryKey' then 20
			when 'UniqueKey' then 30
			when 'UniqueIndex' then 40
			when 'Index' then 50
			when 'ColumnStore' then 60
			when 'XMLPrimary' then 70
			else 80
		end 
	open c
	fetch next from c into @SQL
	while @@fetch_status = 0
	begin
		if @PrintCode = 1
			exec z.usp_PrintString @SQL
		exec(@SQL)
		fetch next from c into @SQL
	end
	close c
	deallocate c
	exec z.usp_ForceNamingConvention @FullTargetTableName
end