/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/versions/0.0.1/z.TaskQueueTasks.ExecutionIndexes.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/docs/readme.md#task-table

Migrates retired task states and known completion expressions atomically, preserving supported execution indexes.
*/
set quoted_identifier on;
set ansi_nulls, ansi_padding, ansi_warnings, arithabort, concat_null_yields_null on;
set numeric_roundabort off;
set xact_abort on;

declare @ObjectID int = object_id(N'z.TaskQueueTasks', N'U');
if @ObjectID is not null
begin
	begin try
		begin tran;
		declare @LockProbe int;
		select top (1) @LockProbe = 1 from z.TaskQueueTasks with (tablockx, holdlock);
		declare	@ExpectedDefinition nvarchar(max) = N'convert(tinyint, case
		when Status = ''Succeeded'' then case when CompletionCondition = ''Failed'' then 1 else 2 end
		when Status = ''Failed'' and AttemptsStarted = 2147483647 then case when CompletionCondition = ''Succeeded'' then 1 else 2 end
		when Status = ''Failed'' and convert(bigint, AttemptsStarted) >= convert(bigint, MaxRetries) + 1 then case when CompletionCondition = ''Succeeded'' then 1 else 2 end
		else 0 end)',
				@LegacyDefinition nvarchar(max) = N'convert(tinyint, case
		when Status = ''Blocked'' or Status = ''NeedsReview'' then 1
		when Status = ''Succeeded'' then case when CompletionCondition = ''Failed'' then 1 else 2 end
		when Status = ''Failed'' and convert(bigint, AttemptsStarted) >= convert(bigint, MaxRetries) + 1 then case when CompletionCondition = ''Succeeded'' then 1 else 2 end
		else 0 end)', @ActualDefinition nvarchar(max), @Sql nvarchar(max),
				@CompletionColumnID int = columnproperty(@ObjectID, N'CompletionState', 'ColumnId'), @CompletionPersisted bit, @ReplaceCompletion bit = 0;
		if @CompletionColumnID is not null
		begin
			select	@ActualDefinition = definition, @CompletionPersisted = is_persisted from sys.computed_columns
			where object_id = @ObjectID and column_id = @CompletionColumnID and system_type_id = type_id(N'tinyint') and max_length = 1;
			if @ActualDefinition is null or isnull(columnproperty(@ObjectID, N'CompletionState', 'IsDeterministic'), 0) <> 1
				or isnull(columnproperty(@ObjectID, N'CompletionState', 'IsPrecise'), 0) <> 1
				throw 50000, 'TaskQueueTasks.CompletionState must be the expected deterministic tinyint computed column; review it before deployment.', 1;
		end;

		declare @Definitions table (DefinitionKind char(1) primary key, Definition nvarchar(max));
		insert @Definitions (DefinitionKind, Definition) values ('E', @ExpectedDefinition), ('L', @LegacyDefinition), ('A', @ActualDefinition);
		-- Preserve literal case and bigint conversion boundaries while ignoring formatting.
		update @Definitions set Definition = replace(replace(replace(replace(Definition collate Latin1_General_100_BIN2,
			N'''Blocked''', N'!blocked!'), N'''NeedsReview''', N'!needsreview!'), N'''Succeeded''', N'!succeeded!'), N'''Failed''', N'!failed!');
		update @Definitions set Definition = lower(replace(translate(Definition collate Latin1_General_100_BIN2,
			nchar(9) + nchar(10) + nchar(11) + nchar(12) + nchar(13) + N'[]', N'       '), N' ', N''));
		update @Definitions set Definition = replace(replace(Definition collate Latin1_General_100_BIN2,
			N'convert(bigint,attemptsstarted)', N'!attempts64!'), N'convert(bigint,maxretries)', N'!retries64!');
		update @Definitions set Definition = replace(replace(Definition, N'(', N''), N')', N'');
		if @CompletionColumnID is not null
		begin
			if not exists
			(
				select	1 from @Definitions a inner join @Definitions e
					on a.Definition collate Latin1_General_100_BIN2 = e.Definition collate Latin1_General_100_BIN2
				where a.DefinitionKind = 'A' and e.DefinitionKind in ('E', 'L')
			)
				throw 50000, 'TaskQueueTasks.CompletionState has an unrecognized expression; review it before deployment.', 1;
			if (select Definition from @Definitions where DefinitionKind = 'A') collate Latin1_General_100_BIN2
				= (select Definition from @Definitions where DefinitionKind = 'L') collate Latin1_General_100_BIN2
				select	@ReplaceCompletion = 1;
		end;

		declare	@StatusCheckID int, @StatusDefinition nvarchar(max), @StatusKind char(1) = 'M',
				@StatusNotForReplication bit = 0, @StatusDisabled bit, @StatusUntrusted bit;
		select	@StatusCheckID = object_id, @StatusDefinition = definition, @StatusNotForReplication = is_not_for_replication,
				@StatusDisabled = is_disabled, @StatusUntrusted = is_not_trusted
		from sys.check_constraints where parent_object_id = @ObjectID and name = N'CK_z_TaskQueueTasks_Status';
		if @StatusCheckID is not null
		begin
			select	@StatusDefinition = replace(replace(replace(replace(replace(replace(@StatusDefinition collate Latin1_General_100_BIN2,
				N'''Pending''', N'!pending!'), N'''Running''', N'!running!'), N'''Succeeded''', N'!succeeded!'), N'''Failed''', N'!failed!'), N'''Blocked''', N'!blocked!'), N'''NeedsReview''', N'!needsreview!');
			select	@StatusDefinition = lower(replace(translate(@StatusDefinition collate Latin1_General_100_BIN2,
				nchar(9) + nchar(10) + nchar(11) + nchar(12) + nchar(13) + N'[]()', N'         '), N' ', N''));
			-- SQL Server may expose an IN list as OR comparisons, in any literal order.
			if left(@StatusDefinition, 8) = N'statusin'
				select	@StatusDefinition = substring(@StatusDefinition, 9, len(@StatusDefinition));
			else
				select	@StatusDefinition = replace(replace(@StatusDefinition, N'or', N','), N'status=', N'');
			declare @StatusTerms table (Term nvarchar(max));
			insert @StatusTerms (Term) select value from string_split(@StatusDefinition, N',');
			if (select count(distinct Term) from @StatusTerms) = 4
				and not exists (select 1 from @StatusTerms where Term collate Latin1_General_100_BIN2 not in (N'!pending!', N'!running!', N'!succeeded!', N'!failed!'))
				select	@StatusKind = 'C';
			else if (select count(distinct Term) from @StatusTerms) = 6
				and not exists (select 1 from @StatusTerms where Term collate Latin1_General_100_BIN2 not in (N'!pending!', N'!running!', N'!succeeded!', N'!failed!', N'!blocked!', N'!needsreview!'))
				select	@StatusKind = 'L';
			else
				throw 50000, 'TaskQueueTasks has an unrecognized status constraint; review it before deployment.', 1;
		end;

		declare @ExpectedIndexes table (IndexName sysname primary key, FilterDefinition nvarchar(128), KeyCount int not null, IncludeCount int not null);
		insert @ExpectedIndexes (IndexName, FilterDefinition, KeyCount, IncludeCount)
			values (N'IX_z_TaskQueueTasks_BatchID_CompletionState_SortOrder_TaskID', null, 4, 6), (N'IX_z_TaskQueueTasks_BatchID_TaskID', N'status=!running!', 2, 0);
		declare @ExpectedColumns table (IndexName sysname, ColumnName sysname, KeyOrdinal int, IsIncludedColumn bit);
		insert @ExpectedColumns (IndexName, ColumnName, KeyOrdinal, IsIncludedColumn)
			values (N'IX_z_TaskQueueTasks_BatchID_CompletionState_SortOrder_TaskID', N'BatchID', 1, 0), (N'IX_z_TaskQueueTasks_BatchID_CompletionState_SortOrder_TaskID', N'CompletionState', 2, 0),
				(N'IX_z_TaskQueueTasks_BatchID_CompletionState_SortOrder_TaskID', N'SortOrder', 3, 0), (N'IX_z_TaskQueueTasks_BatchID_CompletionState_SortOrder_TaskID', N'TaskID', 4, 0),
				(N'IX_z_TaskQueueTasks_BatchID_CompletionState_SortOrder_TaskID', N'Status', 0, 1), (N'IX_z_TaskQueueTasks_BatchID_CompletionState_SortOrder_TaskID', N'AvailableAtUTC', 0, 1),
				(N'IX_z_TaskQueueTasks_BatchID_CompletionState_SortOrder_TaskID', N'AttemptsStarted', 0, 1), (N'IX_z_TaskQueueTasks_BatchID_CompletionState_SortOrder_TaskID', N'MaxRetries', 0, 1),
				(N'IX_z_TaskQueueTasks_BatchID_CompletionState_SortOrder_TaskID', N'RetryIntervalSecond', 0, 1), (N'IX_z_TaskQueueTasks_BatchID_CompletionState_SortOrder_TaskID', N'CompletionCondition', 0, 1),
				(N'IX_z_TaskQueueTasks_BatchID_TaskID', N'BatchID', 1, 0), (N'IX_z_TaskQueueTasks_BatchID_TaskID', N'TaskID', 2, 0);
		declare @CompatibleIndexes table (IndexName sysname, IndexID int);
		insert @CompatibleIndexes (IndexName, IndexID)
			select	e.IndexName, i.index_id
			from @ExpectedIndexes e
				cross join sys.indexes i
				cross apply (values (lower(replace(translate(replace(i.filter_definition collate Latin1_General_100_BIN2,
					N'''Running''', N'!running!'), nchar(9) + nchar(10) + nchar(11) + nchar(12) + nchar(13) + N'[]()', N'         '), N' ', N'')))) f(FilterDefinition)
			where i.object_id = @ObjectID and i.type = 2 and i.is_unique = 0 and i.is_disabled = 0 and i.is_hypothetical = 0
				and i.has_filter = case when e.FilterDefinition is null then 0 else 1 end
				and isnull(f.FilterDefinition, N'') collate Latin1_General_100_BIN2 = isnull(e.FilterDefinition, N'') collate Latin1_General_100_BIN2
				and (select count(*) from sys.index_columns c where c.object_id = @ObjectID and c.index_id = i.index_id and c.key_ordinal > 0) = e.KeyCount
				and (select count(*) from sys.index_columns c where c.object_id = @ObjectID and c.index_id = i.index_id and c.is_included_column = 1) = e.IncludeCount
				and not exists (select 1 from sys.index_columns c where c.object_id = @ObjectID and c.index_id = i.index_id and c.key_ordinal > 0 and c.is_descending_key = 1)
				and not exists
				(
					select	c.ColumnName, c.KeyOrdinal, c.IsIncludedColumn from @ExpectedColumns c where c.IndexName = e.IndexName
					except
					select	d.name, c.key_ordinal, c.is_included_column
					from sys.index_columns c
						inner join sys.columns d on d.object_id = c.object_id and d.column_id = c.column_id
					where c.object_id = @ObjectID and c.index_id = i.index_id and (c.key_ordinal > 0 or c.is_included_column = 1)
				);
		if exists
		(
			select	1 from sys.indexes i
				inner join @ExpectedIndexes e on e.IndexName = i.name
			where i.object_id = @ObjectID and not exists (select 1 from @CompatibleIndexes c where c.IndexName = e.IndexName and c.IndexID = i.index_id)
		)
			throw 50000, 'An existing TaskQueue execution index name has an incompatible definition; review it before deployment.', 1;

		declare @RebuildIndexes table (IndexID int primary key, DropSql nvarchar(max), CreateSql nvarchar(max));
		if @ReplaceCompletion = 1
		begin
			if @CompletionPersisted = 1
				throw 50000, 'The legacy CompletionState column is persisted; preserve or migrate its storage explicitly before deployment.', 1;
			if exists
			(
				select	1 from sys.index_columns c
				where c.object_id = @ObjectID and c.column_id = @CompletionColumnID
					and not exists (select 1 from @CompatibleIndexes i where i.IndexID = c.index_id and i.IndexName = N'IX_z_TaskQueueTasks_BatchID_CompletionState_SortOrder_TaskID')
			)
				throw 50000, 'CompletionState has an unsupported dependent index; preserve or migrate it explicitly before deployment.', 1;
			if exists
			(
				select	1 from @CompatibleIndexes c
					inner join sys.indexes i on i.object_id = @ObjectID and i.index_id = c.IndexID
					inner join sys.stats s on s.object_id = i.object_id and s.stats_id = i.index_id
					left join sys.data_spaces d on d.data_space_id = i.data_space_id
				where c.IndexName = N'IX_z_TaskQueueTasks_BatchID_CompletionState_SortOrder_TaskID'
					and (isnull(d.type, '') <> 'FG' or (select count(*) from sys.partitions p where p.object_id = @ObjectID and p.index_id = i.index_id) <> 1
						or s.is_incremental = 1 or s.has_persisted_sample = 1 or s.is_temporary = 1 or s.stats_generation_method <> 0 or i.suppress_dup_key_messages = 1
						or exists (select 1 from sys.extended_properties e where e.class = 7 and e.major_id = @ObjectID and e.minor_id = i.index_id)
						or exists (select 1 from sys.partitions p where p.object_id = @ObjectID and p.index_id = i.index_id and p.data_compression not in (0, 1, 2)))
			)
				throw 50000, 'CompletionState index migration supports ordinary filegroups, one partition, NONE/ROW/PAGE compression and ordinary statistics without persisted sampling or index properties; review its placement/options.', 1;
			if exists
			(
				select	1 from sys.stats_columns c inner join sys.stats s on s.object_id = c.object_id and s.stats_id = c.stats_id
				where c.object_id = @ObjectID and c.column_id = @CompletionColumnID
					and not exists (select 1 from @CompatibleIndexes i where i.IndexID = c.stats_id and i.IndexName = N'IX_z_TaskQueueTasks_BatchID_CompletionState_SortOrder_TaskID')
			)
				throw 50000, 'CompletionState has standalone statistics; preserve or migrate them explicitly before deployment.', 1;
			if exists (select 1 from sys.extended_properties where class = 1 and major_id = @ObjectID and minor_id = @CompletionColumnID)
				or exists (select 1 from sys.database_permissions where class = 1 and major_id = @ObjectID and minor_id = @CompletionColumnID)
				or exists (select 1 from sys.sql_expression_dependencies where referenced_id = @ObjectID and referenced_minor_id = @CompletionColumnID and is_schema_bound_reference = 1)
				throw 50000, 'CompletionState has column metadata or schema-bound dependencies; preserve or migrate them explicitly before deployment.', 1;
			-- Explicit 100 preserves the full-page meaning of stored fill factor 0 without using server defaults.
			insert @RebuildIndexes (IndexID, DropSql, CreateSql)
				select	i.index_id, N'drop index ' + quotename(i.name) + N' on z.TaskQueueTasks;',
						N'create index ' + quotename(i.name) + N' on z.TaskQueueTasks (BatchID, CompletionState, SortOrder, TaskID) include (' + inc.ColumnNames + N') with ('
						+ N'fillfactor = ' + convert(nvarchar(3), iif(i.fill_factor = 0, 100, i.fill_factor)) + N', pad_index = ' + iif(i.is_padded = 1, N'on', N'off')
						+ N', allow_row_locks = ' + iif(i.allow_row_locks = 1, N'on', N'off') + N', allow_page_locks = ' + iif(i.allow_page_locks = 1, N'on', N'off')
						+ N', statistics_norecompute = ' + iif(s.no_recompute = 1, N'on', N'off')
						+ N', optimize_for_sequential_key = ' + iif(i.optimize_for_sequential_key = 1, N'on', N'off')
						+ N', data_compression = ' + lower(p.data_compression_desc) + N') on ' + quotename(d.name) + N';'
				from @CompatibleIndexes c
					inner join sys.indexes i on i.object_id = @ObjectID and i.index_id = c.IndexID
					inner join sys.stats s on s.object_id = i.object_id and s.stats_id = i.index_id
					inner join sys.partitions p on p.object_id = i.object_id and p.index_id = i.index_id
					inner join sys.data_spaces d on d.data_space_id = i.data_space_id
					cross apply
					(
						select	string_agg(convert(nvarchar(max), quotename(d.name)), N', ') within group (order by k.index_column_id) ColumnNames
						from sys.index_columns k inner join sys.columns d on d.object_id = k.object_id and d.column_id = k.column_id
						where k.object_id = @ObjectID and k.index_id = i.index_id and k.is_included_column = 1
					) inc
				where c.IndexName = N'IX_z_TaskQueueTasks_BatchID_CompletionState_SortOrder_TaskID';
		end;

		-- Keep attempt counts, payloads, retry settings and prior diagnostics; never fabricate a failed attempt.
		declare @Now datetime2(7) = sysutcdatetime();
		update z.TaskQueueTasks
		set Status = case when AttemptsStarted = 0 then 'Pending' else 'Failed' end,
			AvailableAtUTC = case when AttemptsStarted = 0 then AvailableAtUTC
				else dateadd(second, iif(RetryIntervalSecond = 0, 1, RetryIntervalSecond), @Now) end,
			ClaimToken = null, WorkerSessionID = null, WorkerLoginTime = null
		where Status in ('Blocked', 'NeedsReview');
		if @StatusKind = 'L'
			exec(N'alter table z.TaskQueueTasks drop constraint CK_z_TaskQueueTasks_Status;');
		if @StatusKind in ('L', 'M')
		begin
			select	@Sql = N'alter table z.TaskQueueTasks with check add constraint CK_z_TaskQueueTasks_Status check '
					+ iif(@StatusNotForReplication = 1, N'not for replication ', N'') + N'(Status in (''Pending'', ''Running'', ''Succeeded'', ''Failed''));';
			exec(@Sql);
		end
		else if @StatusDisabled = 1 or @StatusUntrusted = 1
			exec(N'alter table z.TaskQueueTasks with check check constraint CK_z_TaskQueueTasks_Status;');

		if @ReplaceCompletion = 1
		begin
			select	@Sql = string_agg(convert(nvarchar(max), DropSql), nchar(13) + nchar(10)) within group (order by IndexID) from @RebuildIndexes;
			if @Sql is not null exec(@Sql);
			exec(N'alter table z.TaskQueueTasks drop column CompletionState;');
		end;
		if @CompletionColumnID is null or @ReplaceCompletion = 1
		begin
			select	@Sql = N'alter table z.TaskQueueTasks add CompletionState as ' + @ExpectedDefinition + N';';
			exec(@Sql);
		end;
		if @ReplaceCompletion = 1
		begin
			select	@Sql = string_agg(convert(nvarchar(max), CreateSql), nchar(13) + nchar(10)) within group (order by IndexID) from @RebuildIndexes;
			if @Sql is not null exec(@Sql);
		end;
		if not exists (select 1 from @CompatibleIndexes where IndexName = N'IX_z_TaskQueueTasks_BatchID_CompletionState_SortOrder_TaskID')
			exec(N'create index IX_z_TaskQueueTasks_BatchID_CompletionState_SortOrder_TaskID on z.TaskQueueTasks (BatchID, CompletionState, SortOrder, TaskID) include (Status, AvailableAtUTC, AttemptsStarted, MaxRetries, RetryIntervalSecond, CompletionCondition) with (data_compression = row);');
		if not exists (select 1 from @CompatibleIndexes where IndexName = N'IX_z_TaskQueueTasks_BatchID_TaskID')
			exec(N'create index IX_z_TaskQueueTasks_BatchID_TaskID on z.TaskQueueTasks (BatchID, TaskID) where Status = ''Running'' with (data_compression = row);');
		commit;
	end try
	begin catch
		if @@trancount > 0 rollback;
		throw;
	end catch;
end;
