create or alter procedure z.usp_CopyTableSchema
(
	@FullSourceTableName nvarchar(256),
	@FullTargetTableName nvarchar(256),
	@FileGroupOrPartitionScheme nvarchar(128) = null,
	@DropTargetTableIfExists bit = 0,
	@CopyIdentity bit = 1,
	@CopyTableSchema bit = 1,
	@CopyIndexes bit = 1,
	@CopyXMLIndexes bit = 1,
	@CopyDefault bit = 1,
	@ScriptAfterTableCreation nvarchar(max) = null,
	@DataCompression varchar(20) = null,
	@PrintCode bit = 0,
	@PartitionNumber int = 1,
	@ShowPlan bit = 0
)
as
begin
	set nocount on;
	set implicit_transactions off;
	declare @SQL nvarchar(max), @InitialTransactionCount int = @@trancount,
			@Savepoint varchar(32) = 'Copy_' + left(replace(convert(varchar(36), newid()), '-', ''), 27),
			@SavepointEstablished bit = 0, @TargetObjectID int;
	declare @ObjectID int = object_id(@FullSourceTableName, N'U'), @BaseIndexID int,
			@TargetTableName sysname = parsename(@FullTargetTableName, 1), @TargetSchemaName sysname = parsename(@FullTargetTableName, 2),
			@BaseFunctionID int, @BasePartitionColumnID int, @PlacementOverride nvarchar(600), @OverrideIsScheme bit = 0, @QuotedTarget nvarchar(517),
			@SchemeName sysname, @SchemeColumn sysname, @OpenParenthesis int,
			@Error nvarchar(2048), @BaseFileGroup sysname, @BaseCompression varchar(20),
			@LobFileGroup sysname, @HasLob bit, @Columns nvarchar(max);

	create table #CopySchemaScript (Ordinal int, PartName varchar(30), Definition nvarchar(max));

	select @PartitionNumber = isnull(@PartitionNumber, 1), @DataCompression = upper(nullif(trim(@DataCompression), ''));
	if @ObjectID is null or parsename(@FullSourceTableName, 3) is not null or parsename(@FullSourceTableName, 4) is not null
		select @Error = N'Source must be a visible user table in the current database.';
	else if @TargetTableName is null or @TargetSchemaName is null or schema_id(@TargetSchemaName) is null
			or parsename(@FullTargetTableName, 3) is not null or parsename(@FullTargetTableName, 4) is not null
		select @Error = N'Target must be a two-part table name in an existing schema in the current database.';
	else if object_id(@FullTargetTableName) = @ObjectID
		select @Error = N'Source and target must be different tables.';
	else if @PartitionNumber < 1
		select @Error = N'PartitionNumber must be positive.';
	else if @DataCompression is not null and @DataCompression not in ('NONE', 'ROW', 'PAGE', 'COLUMNSTORE', 'COLUMNSTORE_ARCHIVE')
		select @Error = N'Unsupported DataCompression value.';

	if @Error is not null throw 50001, @Error, 1;

	select @QuotedTarget = quotename(@TargetSchemaName) + N'.' + quotename(@TargetTableName);
	select @BaseIndexID = i.index_id, @BaseFunctionID = ps.function_id
		from sys.indexes i left join sys.partition_schemes ps on ps.data_space_id = i.data_space_id
		where i.object_id = @ObjectID and i.index_id in (0, 1);
	select @BasePartitionColumnID = column_id from sys.index_columns
		where object_id = @ObjectID and index_id = @BaseIndexID and partition_ordinal = 1;

	if @Error is null and not exists(select * from sys.partitions where object_id = @ObjectID and index_id = @BaseIndexID and partition_number = @PartitionNumber)
		select @Error = N'The selected source partition does not exist.';
	if @Error is null and @BaseFunctionID is null and @PartitionNumber <> 1
		select @Error = N'A nonpartitioned source accepts only partition 1.';
	if @Error is null and exists(select * from sys.tables where object_id = @ObjectID
		and (is_memory_optimized = 1 or temporal_type <> 0 or is_filetable = 1 or is_node = 1 or is_edge = 1 or filestream_data_space_id <> 0))
		select @Error = N'Memory-optimized, temporal, graph, FileTable and FILESTREAM tables are not supported.';
	if @Error is null and exists(select * from sys.columns where object_id = @ObjectID
		and (is_sparse = 1 or is_column_set = 1 or generated_always_type <> 0 or is_hidden = 1 or encryption_type is not null or is_filestream = 1 or rule_object_id <> 0))
		select @Error = N'Sparse, generated, hidden, encrypted, FILESTREAM and rule-bound columns are not supported.';
	if @Error is null and exists(select * from sys.masked_columns where object_id = @ObjectID and is_masked = 1)
		select @Error = N'Masked columns are not supported.';
	if @Error is null and exists(select * from sys.indexes where object_id = @ObjectID and (type not in (0, 1, 2, 3, 5, 6) or is_disabled = 1 or is_hypothetical = 1))
		select @Error = N'Unsupported, disabled or hypothetical source indexes cannot be copied.';
	if @Error is null and exists(select * from sys.xml_indexes where object_id = @ObjectID and xml_index_type_description not in ('PRIMARY_XML', 'SECONDARY_XML'))
		select @Error = N'Selective XML indexes are not supported.';

	if @Error is null and exists(select * from sys.indexes i join sys.partition_schemes ps on ps.data_space_id = i.data_space_id where i.object_id = @ObjectID and @BaseFunctionID is null)
		select @Error = N'A nonpartitioned base table with partitioned secondary indexes is not supported.';
	if @Error is null and exists(select * from sys.columns c where c.object_id = @ObjectID
		and ((c.system_type_id in (165, 167, 173, 175) and c.is_ansi_padded = 0)
			or (c.default_object_id <> 0 and not exists(select * from sys.default_constraints d where d.object_id = c.default_object_id))))
		select @Error = N'Legacy ANSI_PADDING OFF columns and standalone bound defaults cannot be reproduced.';
	if @Error is null and exists(select * from sys.fulltext_indexes where object_id = @ObjectID)
		select @Error = N'Full-text indexes are not supported.';
	-- Catalog serialization keeps optional 2022/2025 fields compatible with the 2019 baseline.
	if @Error is null and exists
	(
		select * from sys.partitions p cross apply(select (select p.* for xml raw, type) Metadata) m
		where (p.object_id = @ObjectID or exists(select * from sys.internal_tables t where t.object_id = p.object_id and t.parent_id = @ObjectID)) and m.Metadata.exist('/row[@xml_compression="1"]') = 1
	)
		select @Error = N'XML compression is not supported by schema copy.';
	if @Error is null and exists
	(
		select * from sys.index_columns c cross apply(select (select c.* for xml raw, type) Metadata) m
		where c.object_id = @ObjectID and m.Metadata.exist('/row[@column_store_order_ordinal > 0 or @data_clustering_ordinal > 0]') = 1
	)
		select @Error = N'Ordered or data-clustered columnstore indexes are not supported.';
	if @Error is null and @DataCompression is not null and @DataCompression <> 'NONE' and exists(select * from sys.xml_indexes where object_id = @ObjectID)
		select @Error = N'DataCompression overrides other than NONE are not supported for XML indexes.';

	-- Equivalent partition functions may use different schemes and destination filegroups.
	if @Error is null and @BaseFunctionID is not null and exists
	(
		select * from sys.indexes i
			left join sys.partition_schemes ps on ps.data_space_id = i.data_space_id
			left join sys.partition_functions pf on pf.function_id = ps.function_id
			left join sys.partition_functions bf on bf.function_id = @BaseFunctionID
		where i.object_id = @ObjectID and i.type in (1, 2, 5, 6) and
		(
			ps.function_id is null or pf.boundary_value_on_right <> bf.boundary_value_on_right or pf.fanout <> bf.fanout
			or not exists(select * from sys.index_columns c where c.object_id = i.object_id and c.index_id = i.index_id and c.partition_ordinal = 1 and c.column_id = @BasePartitionColumnID)
			or exists
			(
				select system_type_id, user_type_id, max_length, precision, scale, collation_name from sys.partition_parameters where function_id = @BaseFunctionID
				except
				select system_type_id, user_type_id, max_length, precision, scale, collation_name from sys.partition_parameters where function_id = ps.function_id
			)
			or exists
			(
				select boundary_id, value from sys.partition_range_values where function_id = @BaseFunctionID
				except
				select boundary_id, value from sys.partition_range_values where function_id = ps.function_id
			)
		)
	)
		select @Error = N'Partitioned sources require aligned indexes with matching partition columns and partition-function definitions.';

	select @FileGroupOrPartitionScheme = nullif(trim(@FileGroupOrPartitionScheme), N'');
	if replace(@FileGroupOrPartitionScheme, N' ', N'') = N'UseSourceObjectFileGroup'
		select @FileGroupOrPartitionScheme = null;
	else if replace(@FileGroupOrPartitionScheme, N' ', N'') = N'UsedefaultDatabaseFileGroup'
		select @PlacementOverride = quotename(name) from sys.filegroups where is_default = 1;
	else if replace(@FileGroupOrPartitionScheme, N' ', N'') = N'UseSourceObjectPartitionScheme'
	begin
		select @PlacementOverride = quotename(ps.name) + N'(' + quotename(col_name(@ObjectID, @BasePartitionColumnID)) + N')', @OverrideIsScheme = 1
			from sys.partition_schemes ps where ps.function_id = @BaseFunctionID
			and ps.data_space_id = (select data_space_id from sys.indexes where object_id = @ObjectID and index_id = @BaseIndexID);
		if @PlacementOverride is null and @Error is null select @Error = N'The source does not use a partition scheme.';
	end
	else if @FileGroupOrPartitionScheme is not null
	begin
		select @PlacementOverride = quotename(name) from sys.filegroups
			where name = @FileGroupOrPartitionScheme or name = parsename(@FileGroupOrPartitionScheme, 1);
		if @PlacementOverride is null
		begin
			select @OpenParenthesis = charindex(N'(', @FileGroupOrPartitionScheme);
			if @OpenParenthesis > 1 and right(@FileGroupOrPartitionScheme, 1) = N')'
				select @SchemeName = parsename(trim(left(@FileGroupOrPartitionScheme, @OpenParenthesis - 1)), 1),
						@SchemeColumn = parsename(trim(substring(@FileGroupOrPartitionScheme, @OpenParenthesis + 1, len(@FileGroupOrPartitionScheme) - @OpenParenthesis - 1)), 1);
			if exists(select * from sys.partition_schemes where name = @SchemeName)
				and exists(select * from sys.columns where object_id = @ObjectID and name = @SchemeColumn)
				select @PlacementOverride = quotename(@SchemeName) + N'(' + quotename(@SchemeColumn) + N')', @OverrideIsScheme = 1;
			else if @Error is null select @Error = N'Placement override must identify an existing filegroup or PartitionScheme(Column).';
		end
	end

	if @Error is not null throw 50001, @Error, 1;

	select @BaseFileGroup = fg.name, @BaseCompression = case when i.type = 5 then 'NONE' else isnull(@DataCompression, p.data_compression_desc) end
		from sys.indexes i left join sys.partitions p on p.object_id = i.object_id and p.index_id = i.index_id and p.partition_number = @PartitionNumber
			left join sys.partition_schemes ps on ps.data_space_id = i.data_space_id
			left join sys.destination_data_spaces d on d.partition_scheme_id = ps.data_space_id and d.destination_id = @PartitionNumber
			join sys.filegroups fg on fg.data_space_id = case when ps.data_space_id is null then i.data_space_id else d.data_space_id end
		where i.object_id = @ObjectID and i.index_id = @BaseIndexID;
	declare @Indexes table
	(
		IndexID int primary key, IndexType int, PartName varchar(30), IndexName sysname,
		FileGroupName sysname, Compression varchar(20), Placement nvarchar(600),
		IndexColumns nvarchar(max), IncludedColumns nvarchar(max), Options nvarchar(max),
		IsPrimaryKey bit, IsUniqueConstraint bit, IsUnique bit, FilterDefinition nvarchar(max),
		PrimaryXMLIndexID int, XMLSecondaryType varchar(60)
	);
	insert into @Indexes(IndexID, IndexType, PartName, IndexName, FileGroupName, Compression, Placement,
		IndexColumns, IncludedColumns, Options, IsPrimaryKey, IsUniqueConstraint, IsUnique, FilterDefinition, PrimaryXMLIndexID, XMLSecondaryType)
		select i.index_id, i.type,
			case when i.is_primary_key = 1 then 'Primary Key' when i.is_unique_constraint = 1 then 'Unique Key'
				when i.type in (5, 6) then 'Column Store' when i.type = 3 and xi.using_xml_index_id is null then 'Primary XML'
				when i.type = 3 then 'Other XML' when i.is_unique = 1 then 'Unique Index' else 'Index' end,
			z.fn_GetExpectedName(case when i.is_primary_key = 1 then 'PrimaryKey' when i.is_unique_constraint = 1 then 'UniqueKey'
				when i.type in (5, 6) then i.type_desc when i.type = 3 then xi.xml_index_type_description + isnull('_' + xi.secondary_type_desc, '') else 'Index' end,
				@TargetSchemaName, @TargetTableName, k.ColumnNames, null, null),
			case when i.type = 3 then @BaseFileGroup else fg.name end, case when i.type = 3 then 'NONE' else isnull(@DataCompression, p.data_compression_desc) end, isnull(@PlacementOverride, quotename(case when i.type = 3 then @BaseFileGroup else fg.name end)),
			k.ColumnDefinition, inc.ColumnNames,
			case when i.type in (1, 2, 3) then
				N'pad_index = ' + iif(i.is_padded = 1, N'on', N'off')
				+ case when i.fill_factor > 0 then N', fillfactor = ' + convert(nvarchar(3), i.fill_factor) else N'' end
				+ case when i.type in (1, 2) then N', ignore_dup_key = ' + iif(i.ignore_dup_key = 1, N'on', N'off') else N'' end
				+ N', allow_row_locks = ' + iif(i.allow_row_locks = 1, N'on', N'off')
				+ N', allow_page_locks = ' + iif(i.allow_page_locks = 1, N'on', N'off')
				+ case when i.type in (1, 2) then N', optimize_for_sequential_key = ' + iif(v.OptimizeForSequentialKey = 1, N'on', N'off') else N'' end
				+ case when i.type = 3 then N'' when st.no_recompute = 1 then N', statistics_norecompute = on' else N', statistics_norecompute = off' end
			else N'compression_delay = ' + convert(nvarchar(10), isnull(i.compression_delay, 0)) end
			+ case when i.type = 3 then N'' else N', data_compression = ' + lower(isnull(@DataCompression, p.data_compression_desc)) end,
			i.is_primary_key, i.is_unique_constraint, i.is_unique, i.filter_definition, xi.using_xml_index_id, xi.secondary_type_desc
		from sys.indexes i
			left join sys.partitions p on p.object_id = i.object_id and p.index_id = i.index_id
				and p.partition_number = case when @BaseFunctionID is null then 1 else @PartitionNumber end
			left join sys.partition_schemes ps on ps.data_space_id = i.data_space_id
			left join sys.destination_data_spaces d on d.partition_scheme_id = ps.data_space_id and d.destination_id = p.partition_number
			left join sys.filegroups fg on fg.data_space_id = case when ps.data_space_id is null then i.data_space_id else d.data_space_id end
			left join sys.xml_indexes xi on xi.object_id = i.object_id and xi.index_id = i.index_id
			left join sys.stats st on st.object_id = i.object_id and st.stats_id = i.index_id
			left join z.v_Indexes v on v.ObjectID = i.object_id and v.IndexID = i.index_id
			cross apply
			(
				select
					stuff((select N',' + quotename(col_name(c.object_id, c.column_id)) from sys.index_columns c
						where c.object_id = i.object_id and c.index_id = i.index_id and (c.key_ordinal > 0 or i.type = 3)
						order by c.key_ordinal, c.index_column_id for xml path(''), type).value('.', 'nvarchar(max)'), 1, 1, N'') ColumnNames,
					stuff((select N',' + quotename(col_name(c.object_id, c.column_id))
						+ case when i.type in (1, 2) then iif(c.is_descending_key = 1, N' desc', N' asc') else N'' end
						from sys.index_columns c where c.object_id = i.object_id and c.index_id = i.index_id and (c.key_ordinal > 0 or i.type = 3)
						order by c.key_ordinal, c.index_column_id for xml path(''), type).value('.', 'nvarchar(max)'), 1, 1, N'') ColumnDefinition
			) k
			cross apply
			(
				select stuff((select N',' + quotename(col_name(c.object_id, c.column_id)) from sys.index_columns c
					where c.object_id = i.object_id and c.index_id = i.index_id and (c.is_included_column = 1 or i.type = 6 or (i.type = 2 and c.partition_ordinal > 0 and c.key_ordinal = 0))
					order by c.index_column_id for xml path(''), type).value('.', 'nvarchar(max)'), 1, 1, N'') ColumnNames
			) inc
		where i.object_id = @ObjectID and i.index_id > 0;

	if @Error is null and (@BaseFileGroup is null or exists(select * from @Indexes where FileGroupName is null or IndexName is null)
		or (select count(*) from @Indexes) <> (select count(*) from sys.indexes where object_id = @ObjectID and index_id > 0))
		select @Error = N'Could not resolve storage or definitions for every source index at the selected partition.';
	if @Error is null and (@BaseCompression not in ('NONE', 'ROW', 'PAGE')
		or exists(select * from @Indexes where (IndexType in (1, 2, 3) and Compression not in ('NONE', 'ROW', 'PAGE'))
			or (IndexType in (5, 6) and Compression not in ('COLUMNSTORE', 'COLUMNSTORE_ARCHIVE'))))
		select @Error = N'The compression override is incompatible with one or more source index types.';

	if @Error is not null throw 50001, @Error, 1;

	-- Generated names can collide for repeated keys or truncated long identifiers.
	update i set IndexName = left(i.IndexName, 116) + N'_' + convert(nvarchar(10), i.IndexID)
		from @Indexes i where exists(select * from @Indexes d where d.IndexID <> i.IndexID and d.IndexName = i.IndexName);

	select @Columns = stuff
	(
		(
			select N',' + nchar(13) + nchar(10) + nchar(9) + quotename(c.name)
				+ case when c.is_computed = 1 then N' as ' + cc.definition + iif(cc.is_persisted = 1, N' persisted', N'')
					+ iif(cc.is_persisted = 1 and c.is_nullable = 0, N' not null', N'')
				else N' ' + case when t.is_user_defined = 1 then quotename(schema_name(t.schema_id)) + N'.' + quotename(t.name)
					else t.name
					+ case when t.name in ('varchar', 'char', 'varbinary', 'binary') then N'(' + iif(c.max_length = -1, N'max', convert(nvarchar(10), c.max_length)) + N')'
						when t.name in ('nvarchar', 'nchar') then N'(' + iif(c.max_length = -1, N'max', convert(nvarchar(10), c.max_length / 2)) + N')'
						when t.name in ('decimal', 'numeric') then N'(' + convert(nvarchar(10), c.precision) + N',' + convert(nvarchar(10), c.scale) + N')'
						when t.name in ('datetime2', 'datetimeoffset', 'time') then N'(' + convert(nvarchar(10), c.scale) + N')'
						when t.name = 'float' then N'(' + convert(nvarchar(10), c.precision) + N')'
						when t.name = 'xml' and c.xml_collection_id <> 0 then N'(' + iif(c.is_xml_document = 1, N'document ', N'content ')
							+ quotename(schema_name(x.schema_id)) + N'.' + quotename(x.name) + N')' else N'' end end
					+ case when c.collation_name is not null and t.is_user_defined = 0 then N' collate ' + c.collation_name else N'' end
					+ case when c.is_identity = 1 and @CopyIdentity = 1 then N' identity(' + convert(nvarchar(100), id.seed_value)
						+ N',' + convert(nvarchar(100), id.increment_value) + N')' + iif(id.is_not_for_replication = 1, N' not for replication', N'') else N'' end
					+ iif(c.is_rowguidcol = 1, N' rowguidcol', N'')
					+ iif(c.is_nullable = 1, N' null', N' not null') end
			from sys.columns c join sys.types t on t.user_type_id = c.user_type_id
				left join sys.computed_columns cc on cc.object_id = c.object_id and cc.column_id = c.column_id
				left join sys.identity_columns id on id.object_id = c.object_id and id.column_id = c.column_id
				left join sys.xml_schema_collections x on x.xml_collection_id = c.xml_collection_id
			where c.object_id = @ObjectID order by c.column_id for xml path(''), type
		).value('.', 'nvarchar(max)'), 1, 1, N''
	);
	select @HasLob = iif(exists(select * from sys.columns where object_id = @ObjectID and (max_length = -1 or system_type_id in (34, 35, 99, 241))), 1, 0);
	select @LobFileGroup = fg.name from sys.tables t join sys.filegroups fg on fg.data_space_id = t.lob_data_space_id where t.object_id = @ObjectID;
	if @BaseFunctionID is not null select @LobFileGroup = @BaseFileGroup;
	if @PlacementOverride is not null and @OverrideIsScheme = 0 select @LobFileGroup = parsename(@PlacementOverride, 1);

	insert into #CopySchemaScript values
		(10000, 'Table', N'create table ' + @QuotedTarget + nchar(13) + nchar(10) + N'(' + @Columns + nchar(13) + nchar(10)
			+ N') on ' + isnull(@PlacementOverride, quotename(@BaseFileGroup))
			+ case when @HasLob = 1 and @LobFileGroup is not null and @OverrideIsScheme = 0
				then N' textimage_on ' + quotename(@LobFileGroup) else N'' end + N' with (data_compression = ' + lower(@BaseCompression) + N');');
	insert into #CopySchemaScript(Ordinal, PartName, Definition)
		select 10002, 'Table Options', N'alter table ' + @QuotedTarget + N' set (lock_escalation = ' + lower(lock_escalation_desc) + N');'
			+ case when large_value_types_out_of_row = 1 then N' exec sys.sp_tableoption N''' + replace(@QuotedTarget, N'''', N'''''')
				+ N''', N''large value types out of row'', N''1'';' else N'' end
			+ case when text_in_row_limit > 0 then N' exec sys.sp_tableoption N''' + replace(@QuotedTarget, N'''', N'''''')
				+ N''', N''text in row'', N''' + convert(nvarchar(10), text_in_row_limit) + N''';' else N'' end
		from sys.tables where object_id = @ObjectID;

	insert into #CopySchemaScript(Ordinal, PartName, Definition)
		select 20000 + row_number() over(order by case when i.IndexType <> 3 then 0 when i.PrimaryXMLIndexID is null then 1 else 2 end, i.IndexID), i.PartName,
			case when i.IndexType in (1, 2) then
				case when i.IsPrimaryKey = 1 or i.IsUniqueConstraint = 1 then
					N'alter table ' + @QuotedTarget + N' add constraint ' + quotename(i.IndexName)
					+ iif(i.IsPrimaryKey = 1, N' primary key ', N' unique ') + iif(i.IndexType = 1, N'clustered', N'nonclustered')
				else N'create ' + iif(i.IsUnique = 1, N'unique ', N'') + iif(i.IndexType = 1, N'clustered', N'nonclustered')
					+ N' index ' + quotename(i.IndexName) + N' on ' + @QuotedTarget end
				+ N' (' + i.IndexColumns + N')' + isnull(N' include (' + i.IncludedColumns + N')', N'')
				+ isnull(N' where ' + i.FilterDefinition, N'') + N' with (' + i.Options + N') on ' + i.Placement + N';'
			when i.IndexType in (5, 6) then
				N'create ' + iif(i.IndexType = 5, N'clustered', N'nonclustered') + N' columnstore index ' + quotename(i.IndexName)
				+ N' on ' + @QuotedTarget + case when i.IndexType = 6 then N' (' + i.IncludedColumns + N')' else N'' end
				+ isnull(N' where ' + i.FilterDefinition, N'') + N' with (' + i.Options + N') on ' + i.Placement + N';'
			when i.IndexType = 3 then
				N'create ' + iif(i.PrimaryXMLIndexID is null, N'primary ', N'') + N'xml index ' + quotename(i.IndexName)
				+ N' on ' + @QuotedTarget + N' (' + i.IndexColumns + N')'
				+ case when i.PrimaryXMLIndexID is not null then N' using xml index ' + quotename(p.IndexName) + N' for ' + lower(i.XMLSecondaryType) else N'' end
				+ N' with (' + i.Options + N');' end
		from @Indexes i left join @Indexes p on p.IndexID = i.PrimaryXMLIndexID;

	insert into #CopySchemaScript(Ordinal, PartName, Definition)
		select 30000 + c.column_id, 'Default', N'alter table ' + @QuotedTarget + N' add constraint '
			+ quotename(left(z.fn_GetExpectedName('Default', @TargetSchemaName, @TargetTableName, c.name, null, null), 116) + N'_' + convert(nvarchar(10), c.column_id))
			+ N' default ' + d.definition + N' for ' + quotename(c.name) + N';'
		from sys.columns c join sys.default_constraints d on d.object_id = c.default_object_id where c.object_id = @ObjectID;
	select @TargetObjectID = object_id(@QuotedTarget);
	if @DropTargetTableIfExists = 1 and isnull(@CopyTableSchema, 0) = 0
		throw 50001, N'Dropping the target requires CopyTableSchema = 1.', 1;
	if @TargetObjectID is not null and object_id(@QuotedTarget, N'U') is null
		throw 50001, N'The target name is occupied by an object that is not a user table.', 1;
	if @CopyTableSchema = 1 and @TargetObjectID is not null and isnull(@DropTargetTableIfExists, 0) = 0 and isnull(@ShowPlan, 0) = 0
		throw 50001, N'The target already exists. Set DropTargetTableIfExists = 1 to replace it.', 1;
	if isnull(@CopyTableSchema, 0) = 0 and @TargetObjectID is null
		throw 50001, N'CopyTableSchema = 0 requires an existing target table.', 1;

	insert into #CopySchemaScript(Ordinal, PartName, Definition)
		select 10001, 'After Table', @ScriptAfterTableCreation where @ScriptAfterTableCreation is not null;
	delete from #CopySchemaScript where Definition is null or not
	(
		isnull(@CopyTableSchema, 0) = 1 and PartName in ('Table', 'Table Options')
		or isnull(@CopyIndexes, 0) = 1 and PartName in ('Primary Key', 'Unique Key', 'Unique Index', 'Index', 'Column Store')
		or isnull(@CopyXMLIndexes, 0) = 1 and PartName in ('Primary XML', 'Other XML')
		or isnull(@CopyDefault, 0) = 1 and PartName = 'Default'
		or PartName = 'After Table'
	);
	if @DropTargetTableIfExists = 1 and @TargetObjectID is not null
		insert into #CopySchemaScript values(0, 'Drop Table', N'drop table ' + @QuotedTarget + N';');
	if @ShowPlan = 1
	begin
		select Ordinal, PartName, Definition from #CopySchemaScript order by Ordinal, PartName;
		return;
	end

	set xact_abort on;
	declare CopyParts cursor local fast_forward for
		select Definition from #CopySchemaScript order by Ordinal, PartName;
	begin try
		if @InitialTransactionCount = 0 begin tran;
		else
		begin
			save tran @Savepoint;
			select @SavepointEstablished = 1;
		end
		open CopyParts;
		fetch next from CopyParts into @SQL;
		while @@fetch_status = 0
		begin
			if @PrintCode = 1 exec z.usp_PrintString @SQL;
			exec sys.sp_executesql @SQL;
			fetch next from CopyParts into @SQL;
		end
		close CopyParts;
		deallocate CopyParts;
		if @InitialTransactionCount = 0 commit;
	end try
	begin catch
		if cursor_status('local', 'CopyParts') >= 0 close CopyParts;
		if cursor_status('local', 'CopyParts') >= -1 deallocate CopyParts;
		if @InitialTransactionCount = 0 and @@trancount > 0 rollback;
		else if @SavepointEstablished = 1 and xact_state() = 1 rollback tran @Savepoint;
		throw;
	end catch
end
