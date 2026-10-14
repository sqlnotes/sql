create or alter procedure z.usp_ForceNamingConvention
(
	@TableName nvarchar(256) = null,
	@IgnoreError bit = 0,
	@SchemaNames nvarchar(max) = null,
	@TableNames nvarchar(max) = null,
	@ShowPlan bit = 0
)
as
begin
	set nocount on;
	-- Renames are intentionally non-atomic; never roll back a caller's transaction.
	set xact_abort off;
	declare @ObjectName nvarchar(1200), @NewName nvarchar(128), @ObjectType varchar(13), @ObjectID int,
		@Entry nvarchar(max), @SchemaName sysname, @Name sysname, @Position int, @Dots int,
		@Delimiter nchar(1), @Character nchar(1);
	declare @Schemas table (SchemaID int not null primary key);
	declare @Objects table (ObjectID int not null primary key);
	declare @Entries table (Selector varchar(10) not null, Name nvarchar(max), JsonType int not null);

	if @SchemaNames is not null
	begin
		if isjson(@SchemaNames) <> 1 or left(ltrim(replace(replace(replace(@SchemaNames, nchar(9), N' '), nchar(10), N' '), nchar(13), N' ')), 1) <> N'['
			throw 50001, '@SchemaNames must be a JSON array of schema-name strings.', 1;
		insert @Entries (Selector, Name, JsonType) select 'Schema', value, type from openjson(@SchemaNames);
	end
	if @TableNames is not null
	begin
		if isjson(@TableNames) <> 1 or left(ltrim(replace(replace(replace(@TableNames, nchar(9), N' '), nchar(10), N' '), nchar(13), N' ')), 1) <> N'['
			throw 50001, '@TableNames must be a JSON array of schema-qualified table or view names.', 1;
		insert @Entries (Selector, Name, JsonType) select 'Table', value, type from openjson(@TableNames);
	end
	if exists (select 1 from @Entries where JsonType <> 1 or trim(Name) = N'')
		throw 50001, 'Selector arrays must contain nonempty strings only.', 1;
	if exists (select 1 from @Entries where Selector = 'Schema' and (datalength(Name) > 256 or schema_id(Name) is null))
		throw 50001, '@SchemaNames contains an unknown schema in the current database.', 1;
	insert @Schemas (SchemaID) select distinct schema_id(Name) from @Entries where Selector = 'Schema';

	-- Keep the original single-object and positional calling convention.
	if @TableName is not null
	begin
		select @ObjectID = object_id(@TableName);
		if @ObjectID is null or parsename(@TableName, 4) is not null
			or (parsename(@TableName, 3) is not null and parsename(@TableName, 3) <> db_name())
			or not exists (select 1 from sys.objects where object_id = @ObjectID and type in ('U', 'V'))
			throw 50001, '@TableName must identify a table or view in the current database.', 1;
		insert @Objects (ObjectID) values (@ObjectID);
	end

	declare SelectorCursor cursor local static for select distinct Name from @Entries where Selector = 'Table';
	open SelectorCursor;
	fetch next from SelectorCursor into @Entry;
	while @@fetch_status = 0
	begin
		if datalength(@Entry) > 1034
			throw 50001, '@TableNames contains an identifier longer than two delimited sysnames.', 1;
		select @SchemaName = parsename(@Entry, 2), @Name = parsename(@Entry, 1),
			@Position = 1, @Dots = 0, @Delimiter = null;
		-- Count separators outside delimited names; dots and escaped brackets in names are valid.
		while @Position <= len(@Entry)
		begin
			select @Character = substring(@Entry, @Position, 1);
			if @Delimiter is null
			begin
				if @Character = N'[' select @Delimiter = N']';
				else if @Character = N'"' select @Delimiter = N'"';
				else if @Character = N'.' select @Dots += 1;
			end
			else if @Character = @Delimiter
			begin
				if substring(@Entry, @Position + 1, 1) = @Delimiter select @Position += 1;
				else select @Delimiter = null;
			end
			select @Position += 1;
		end
		if @Dots <> 1 or @Delimiter is not null or @SchemaName is null or @Name is null
			or parsename(@Entry, 3) is not null or parsename(@Entry, 4) is not null
			throw 50001, '@TableNames entries must be exactly schema-qualified names in the current database.', 1;
		select @ObjectID = object_id(quotename(@SchemaName) + N'.' + quotename(@Name));
		if not exists (select 1 from sys.objects where object_id = @ObjectID and type in ('U', 'V'))
			throw 50001, '@TableNames contains an unknown table or view in the current database.', 1;
		if not exists (select 1 from @Objects where ObjectID = @ObjectID) insert @Objects (ObjectID) values (@ObjectID);
		fetch next from SelectorCursor into @Entry;
	end
	close SelectorCursor;
	deallocate SelectorCursor;
	if not exists (select 1 from @Schemas) and not exists (select 1 from @Objects)
		throw 50001, 'Supply at least one schema or table through @SchemaNames, @TableNames or @TableName.', 1;

	insert @Objects (ObjectID)
		select o.object_id from sys.objects o
			join @Schemas s on s.SchemaID = o.schema_id
		where o.type in ('U', 'V') and o.is_ms_shipped = 0
			and not exists (select 1 from @Objects t where t.ObjectID = o.object_id);
	create table #RenamePlan (ObjectName nvarchar(1200) not null, NewName nvarchar(128) not null, ObjectType varchar(13) not null);
	insert #RenamePlan (ObjectName, NewName, ObjectType)
		select case when i.IsPrimaryKey = 1 or i.IsUniqueConstraint = 1 then
				quotename(i.SchemaName) + N'.' + quotename(i.IndexName)
			else quotename(i.SchemaName) + N'.' + quotename(i.ObjectName) + N'.' + quotename(i.IndexName) end,
			i.ExpectedIndexName, case when i.IsPrimaryKey = 1 or i.IsUniqueConstraint = 1 then 'Object' else 'Index' end
		from z.v_Indexes i join @Objects o on o.ObjectID = i.ObjectID
		where i.ExpectedIndexName <> i.IndexName
		union all
		select quotename(d.SchemaName) + N'.' + quotename(d.DefaultName), d.ExpectedDefaultName, 'Object'
		from z.v_DefaultConstraints d join @Objects o on o.ObjectID = d.ParentObjectID
		where d.ExpectedDefaultName <> d.DefaultName
		union all
		select quotename(f.SchemaName) + N'.' + quotename(f.ForeignKeyName), f.ExpectedForeignKeyName, 'Object'
		from z.v_ForeignKeys f join @Objects o on o.ObjectID = f.ParentObjectID
		where f.ExpectedForeignKeyName <> f.ForeignKeyName;
	if @ShowPlan = 1
	begin
		select ObjectName, NewName, ObjectType from #RenamePlan order by ObjectName, ObjectType, NewName;
		return;
	end

	declare RenameCursor cursor local static for
		select ObjectName, NewName, ObjectType from #RenamePlan order by ObjectName, ObjectType, NewName;
	open RenameCursor;
	fetch next from RenameCursor into @ObjectName, @NewName, @ObjectType;
	while @@fetch_status = 0
	begin
		begin try
			print N'Renaming ' + @ObjectName + N' --> ' + @NewName;
			exec sys.sp_rename @objname = @ObjectName, @newname = @NewName, @objtype = @ObjectType;
		end try
		begin catch
			if isnull(@IgnoreError, 0) = 0 throw;
			print error_message();
		end catch
		fetch next from RenameCursor into @ObjectName, @NewName, @ObjectType;
	end
	close RenameCursor;
	deallocate RenameCursor;
end
