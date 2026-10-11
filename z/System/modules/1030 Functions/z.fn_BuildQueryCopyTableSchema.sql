create or alter function z.fn_BuildQueryCopyTableSchema
(
	@FullSourceTableName nvarchar(256),
	@FullTargetTableName nvarchar(256),
	@FileGroupOrPartitionScheme nvarchar(128), -- NULL: 'Use Source Object File Group', 'Use default Database File Group', 'Use Source Object Partition Scheme', FileGroupName or PartitionSchemeName(FieldName)
	@CopyIdentity bit,
	@DataCompression varchar(20)
)
returns @ret table (Ordinal int, PartName varchar(30), Definition nvarchar(max))
as
begin
	declare @ObjectID int = object_id(@FullSourceTableName), 
			@TargetTableName nvarchar(128) = nullif(rtrim(ltrim(parsename(@FullTargetTableName, 1))), ''), 
			@TargetSchemaName nvarchar(128) = nullif(rtrim(ltrim(parsename(@FullTargetTableName, 2))), '')
	if @ObjectID is null
		return
	select @FullTargetTableName  = quotename(@TargetSchemaName) + '.' + quotename(@TargetTableName)
	select @ObjectID = object_id(@FullSourceTableName)
	if @ObjectID is null or @FullTargetTableName  is null
	begin
		return
	end

	if @FileGroupOrPartitionScheme is null
	begin
		select @FileGroupOrPartitionScheme = (
												select top 1 quotename(ds.name)
												from sys.partitions p
													inner join sys.allocation_units au on p.partition_id = au.container_id
													inner join sys.data_spaces ds on ds.data_space_id = au.data_space_id
												where p.object_id = @ObjectID
													and p.index_id in(0, 1)
												)
	end
	else if replace(@FileGroupOrPartitionScheme, ' ', '') = 'UseSourceObjectPartitionScheme'
	begin
		select @FileGroupOrPartitionScheme = (
												select top 1 quotename(PartitionSchemeName) + '('+quotename(PartitionKeyName)+')' 
												from z.v_PartitionedIndexes 
												where ObjectID = @ObjectID 
												and IndexID in(0,1)
											)
	end
	else if replace(@FileGroupOrPartitionScheme, ' ', '') = 'UsedefaultDatabaseFileGroup'
	begin
		select @FileGroupOrPartitionScheme = quotename(name)
			from sys.data_spaces
			where is_default = 1
				and type_desc = 'ROWS_FILEGROUP'
	end

	if @FileGroupOrPartitionScheme is null
		return;
	if charindex('(', @FileGroupOrPartitionScheme) = 0 and charindex('[', @FileGroupOrPartitionScheme) = 0
	begin
		select @FileGroupOrPartitionScheme = quotename(@FileGroupOrPartitionScheme)
	end
	insert into @ret(Ordinal, PartName, Definition)
		select	10000, 'Table',
				cast('create table ' as nvarchar(max)) + @FullTargetTableName + '
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
								from z.v_Objects t
								where t.ObjectID = @ObjectID
								order by t.ColumnID
								for xml path(''), type
							).value('.', 'nvarchar(max)') , 1, 1, '')+'
) on ' + @FileGroupOrPartitionScheme + ';'
			
	insert into @ret(Ordinal, PartName, Definition)
		select	20000 + IndexID,
				case 
					when i.IsPrimaryKey = 1 or isnull(objectproperty(i.ObjectID, 'IsSchemaBound'), 0) = 1 and i.IndexType = 'CLUSTERED' then 'Primary Key'
					when i.IsPrimaryKey = 0 and i.IsUniqueConstraint = 1 then 'Unique Key'
					when i.IsPrimaryKey = 0 and i.IsUniqueConstraint = 0 and i.IsUnique = 1 then 'Unique Index'
					when i.IsPrimaryKey = 0 and i.IsUniqueConstraint = 0 and i.IsUnique = 0 and i.IndexType not like '%columnstore%' and i.IndexType not like '%xml%' then 'Index'
					when i.IsPrimaryKey = 0 and i.IsUniqueConstraint = 0 and i.IsUnique = 0 and i.IndexType = 'NONCLUSTERED COLUMNSTORE' then 'Column Store'
					when i.IsPrimaryKey = 0 and i.IsUniqueConstraint = 0 and i.IsUnique = 0 and i.IndexType = 'CLUSTERED COLUMNSTORE' then 'Column Store'
					when i.IndexType = 'PRIMARY_XML' then 'Primary XML'
					when i.IndexType <> 'PRIMARY_XML' and i.IndexType like '%XML%' then 'Other XML'
				end,
				case 
					when i.IsPrimaryKey = 1 then 
					
						'alter table ' + @FullTargetTableName + ' add constraint ' 
						+ quotename(z.fn_GetExpectedName('PrimaryKey', @TargetSchemaName, @TargetTableName, null, null, null))
						+ ' primary key ' + lower(i.IndexType) collate database_default  
						+' (' + i.IndexColumnDefinition + ')'
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

					when i.IsPrimaryKey = 0 and i.IsUniqueConstraint = 1 then
						'alter table ' + @FullTargetTableName+ ' add constraint ' 
						+ quotename(z.fn_GetExpectedName('UniqueKey', @TargetSchemaName, @TargetTableName, i.IndexColumns, null, null))
						+ ' unique ' + lower(i.IndexType) collate database_default  
						+' (' + i.IndexColumnDefinition + ')'
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

					when i.IsPrimaryKey = 0 and i.IsUniqueConstraint = 0 and i.IsUnique = 1 then
						'create unique ' + lower(i.IndexType)  collate database_default +' index ' 
						+	case 
								when isnull(objectproperty(i.ObjectID, 'IsSchemaBound'), 0) = 1 and i.IndexType = 'CLUSTERED' then
									quotename(z.fn_GetExpectedName('PrimaryKey', @TargetSchemaName, @TargetTableName, null, null, null))
								else
									quotename(z.fn_GetExpectedName('Index', @TargetSchemaName, @TargetTableName, i.IndexColumns, null, null))
							end
						+ ' on ' + @FullTargetTableName 
						+ ' (' + i.IndexColumnDefinition + ')'
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

					when i.IsPrimaryKey = 0 and i.IsUniqueConstraint = 0 and i.IsUnique = 0 and i.IndexType not like '%columnstore%' and i.IndexType not like '%xml%' then
						'create ' + lower(i.IndexType)  collate database_default +' index ' 
						+ quotename(z.fn_GetExpectedName('Index', @TargetSchemaName, @TargetTableName, i.IndexColumns, null, null))
						+ ' on ' + @FullTargetTableName 
						+ ' (' + i.IndexColumnDefinition + ')'
						+ case when i.IncludedColumns is not null then ' include(' + i.IncludedColumns + ')'  else '' end
						+ case when i.FilterDefinition is not null then ' where ' + i.FilterDefinition else '' end 
						+ ' with('
								+ 'pad_index = ' + iif(i.IsPadded = 1, 'on', 'off')
								--+ ', ignore_dup_key = ' + + iif(i.IgnoreDuplicatedKey = 1, 'on', 'off')
								+ ', allow_row_locks = ' + + iif(i.AllowRowLocks = 1, 'on', 'off')
								+ ', allow_page_locks = ' + + iif(i.AllowPageLocks = 1, 'on', 'off')
								+ ', optimize_for_sequential_key = ' + + iif(i.OptimizeForSequentialKey = 1, 'on', 'off')
								+ isnull(',data_compression=' + isnull(@DataCompression, i.Compression), '')
						+') on ' + @FileGroupOrPartitionScheme + ';'

					when i.IsPrimaryKey = 0 and i.IsUniqueConstraint = 0 and i.IsUnique = 0 and i.IndexType = 'NONCLUSTERED COLUMNSTORE' then
						'create ' + lower(i.IndexType)  collate database_default +' index ' 
						+ quotename(z.fn_GetExpectedName(i.IndexType, @TargetSchemaName, @TargetTableName, null, null, null))
						+ ' on ' + @FullTargetTableName 
						+ ' (' + i.IncludedColumns + ')'
						+ ' on ' + @FileGroupOrPartitionScheme + ';'

					when i.IsPrimaryKey = 0 and i.IsUniqueConstraint = 0 and i.IsUnique = 0 and i.IndexType = 'CLUSTERED COLUMNSTORE' then
						'create ' + lower(i.IndexType)  collate database_default +' index ' 
						+ quotename(z.fn_GetExpectedName(i.IndexType, @TargetSchemaName, @TargetTableName, null, null, null))
						+ ' on ' + @FullTargetTableName 
						+ ' on ' + @FileGroupOrPartitionScheme + ';'

					when i.IndexType = 'PRIMARY_XML' then
						'create primary xml index ' 
						+ quotename(z.fn_GetExpectedName(i.IndexType, @TargetSchemaName, @TargetTableName, i.IndexColumns, null, null))
						+ ' on ' + @FullTargetTableName + ' (' + i.IndexColumns + ')'
						+ ' with('
							+ 'pad_index = ' + iif(i.IsPadded = 1, 'on', 'off')
							--+ ', ignore_dup_key = ' + + iif(i.IgnoreDuplicatedKey = 1, 'on', 'off')
							+ ', allow_row_locks = ' + + iif(i.AllowRowLocks = 1, 'on', 'off')
							+ ', allow_page_locks = ' + + iif(i.AllowPageLocks = 1, 'on', 'off')
							+ ', optimize_for_sequential_key = ' + + iif(i.OptimizeForSequentialKey = 1, 'on', 'off')
							+ isnull(',data_compression=' + isnull(@DataCompression, i.Compression), '')
						+');'

					when i.IndexType <> 'PRIMARY_XML' and i.IndexType like '%XML%' then
						'create xml index ' 
						+ quotename(z.fn_GetExpectedName(i.IndexType, @TargetSchemaName, @TargetTableName, i.IndexColumns, null, null))
						+ ' on ' + @FullTargetTableName + ' (' + i.IndexColumns + ')'
						+' using xml index ' + quotename(z.fn_GetExpectedName('PRIMARY_XML', @TargetSchemaName, @TargetTableName, i.IndexColumns, null, null))
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
				end
		from z.v_Indexes i
		where i.ObjectID = @ObjectID
		

		
			
	insert into @ret(Ordinal, PartName, Definition)
		select	30000 + row_number() over(order by d.DefaultName),
				'Default',
				'alter table ' + @FullTargetTableName + '  add constraint ' 
				+ quotename(z.fn_GetExpectedName('Default', @TargetSchemaName, @TargetTableName, d.ParentColumnName, null, null))
				+ ' default ' + d.Definition +' for ' + quotename(d.ParentColumnName) + ';'
		from z.v_DefaultConstraints d
		where d.ParentObjectID = @ObjectID
	return
end
