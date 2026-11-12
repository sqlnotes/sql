/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/versions/0.0.1/z.TaskQueueTasks.ExecutionIndexes.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/docs/readme.md#task-table

Adds derived completion-state and running-task access paths without replacing existing indexes.
*/
set quoted_identifier on;
set ansi_nulls, ansi_padding, ansi_warnings, arithabort, concat_null_yields_null on;
set numeric_roundabort off;

declare @ObjectID int = object_id(N'z.TaskQueueTasks', N'U');
if @ObjectID is not null
begin
	declare @ExpectedDefinition nvarchar(max) = N'convert(tinyint, case
		when Status = ''Blocked'' or Status = ''NeedsReview'' then 1
		when Status = ''Succeeded'' then case when CompletionCondition = ''Failed'' then 1 else 2 end
		when Status = ''Failed'' and convert(bigint, AttemptsStarted) >= convert(bigint, MaxRetries) + 1 then case when CompletionCondition = ''Succeeded'' then 1 else 2 end
		else 0 end)', @ActualDefinition nvarchar(max), @Sql nvarchar(max);
	if not exists (select 1 from sys.columns where object_id = @ObjectID and name = N'CompletionState')
	begin
		select @Sql = N'alter table z.TaskQueueTasks add CompletionState as ' + @ExpectedDefinition + N';';
		exec sys.sp_executesql @Sql;
	end;
	select @ActualDefinition = definition from sys.computed_columns
	where object_id = @ObjectID and name = N'CompletionState' and system_type_id = type_id(N'tinyint') and max_length = 1;
	if @ActualDefinition is null or isnull(columnproperty(@ObjectID, N'CompletionState', 'IsDeterministic'), 0) <> 1
		or isnull(columnproperty(@ObjectID, N'CompletionState', 'IsPrecise'), 0) <> 1
		throw 50000, 'TaskQueueTasks.CompletionState must be the expected deterministic tinyint computed column; review the existing column before deployment.', 1;

	declare @Definitions table (DefinitionKind char(1) primary key, Definition nvarchar(max));
	insert @Definitions (DefinitionKind, Definition) values ('E', @ExpectedDefinition), ('A', @ActualDefinition);
	-- Preserve literal case before normalizing SQL tokens, including on case-sensitive databases.
	update @Definitions set Definition = replace(replace(replace(replace(Definition collate Latin1_General_100_BIN2,
		N'''Blocked''', N'!blocked!'), N'''NeedsReview''', N'!needsreview!'), N'''Succeeded''', N'!succeeded!'), N'''Failed''', N'!failed!');
	update @Definitions set Definition = lower(replace(translate(Definition collate Latin1_General_100_BIN2,
		nchar(9) + nchar(10) + nchar(11) + nchar(12) + nchar(13) + N'[]', N'       '), N' ', N''));
	-- Keep conversion boundaries: converting MaxRetries + 1 afterward can overflow int.
	update @Definitions set Definition = replace(replace(Definition collate Latin1_General_100_BIN2,
		N'convert(bigint,attemptsstarted)', N'!attempts64!'), N'convert(bigint,maxretries)', N'!retries64!');
	update @Definitions set Definition = replace(replace(Definition, N'(', N''), N')', N'');
	if (select Definition from @Definitions where DefinitionKind = 'A') collate Latin1_General_100_BIN2
		<> (select Definition from @Definitions where DefinitionKind = 'E') collate Latin1_General_100_BIN2
		throw 50000, 'TaskQueueTasks.CompletionState has an incompatible expression; review the existing computed column before deployment.', 1;

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
		select e.IndexName, i.index_id
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
				select c.ColumnName, c.KeyOrdinal, c.IsIncludedColumn from @ExpectedColumns c where c.IndexName = e.IndexName
				except
				select d.name, c.key_ordinal, c.is_included_column
				from sys.index_columns c
					join sys.columns d on d.object_id = c.object_id and d.column_id = c.column_id
				where c.object_id = @ObjectID and c.index_id = i.index_id and (c.key_ordinal > 0 or c.is_included_column = 1)
			);
	if exists
	(
		select 1 from sys.indexes i
			join @ExpectedIndexes e on e.IndexName = i.name
		where i.object_id = @ObjectID and not exists (select 1 from @CompatibleIndexes c where c.IndexName = e.IndexName and c.IndexID = i.index_id)
	)
		throw 50000, 'An existing TaskQueue execution index name has an incompatible definition; review it before deployment.', 1;
	if not exists (select 1 from @CompatibleIndexes where IndexName = N'IX_z_TaskQueueTasks_BatchID_CompletionState_SortOrder_TaskID')
		exec sys.sp_executesql N'create index IX_z_TaskQueueTasks_BatchID_CompletionState_SortOrder_TaskID on z.TaskQueueTasks (BatchID, CompletionState, SortOrder, TaskID) include (Status, AvailableAtUTC, AttemptsStarted, MaxRetries, RetryIntervalSecond, CompletionCondition) with (data_compression = row);';
	if not exists (select 1 from @CompatibleIndexes where IndexName = N'IX_z_TaskQueueTasks_BatchID_TaskID')
		exec sys.sp_executesql N'create index IX_z_TaskQueueTasks_BatchID_TaskID on z.TaskQueueTasks (BatchID, TaskID) where Status = ''Running'' with (data_compression = row);';
end;
