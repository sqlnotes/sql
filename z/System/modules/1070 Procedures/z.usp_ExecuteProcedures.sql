/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/modules/1070%20Procedures/z.usp_ExecuteProcedures.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/docs/reference/procedures.md#zusp_executeprocedures

Lists matching procedures in selected databases before executing them, skipping procedures held by another worker.
*/
create or alter procedure z.usp_ExecuteProcedures
(
	@SchemaNames nvarchar(max) = N'%',
	@ProcedureNames nvarchar(max),
	@ExcludedProcedureNames nvarchar(max) = null,
	@DatabaseNames nvarchar(max) = null,
	@ExcludedDatabaseNames nvarchar(max) = null,
	@ExcludedSchemaNames nvarchar(max) = null
)
as
begin
	set nocount, xact_abort on;
	-- A selected procedure can commit even when the caller enabled cursor closing.
	set cursor_close_on_commit off;
	declare	@DatabaseName sysname, @SchemaName sysname, @ProcedureName sysname, @ObjectID int, @CurrentObjectID int,
			@DatabaseExecutor nvarchar(300), @Proc nvarchar(776), @Messages nvarchar(max) = N'', @SemaphoreName nvarchar(200),
			@SemaphoreSlot int;
	declare @Procedures table (DatabaseName sysname not null, SchemaName sysname not null, ProcedureName sysname not null, ObjectID int not null);

	-- Resolve schema and procedure patterns under each target database's catalog collation.
	declare @ListSql nvarchar(max) = N'
select	@DatabaseName DatabaseName, s.name SchemaName, p.name ProcedureName, p.object_id ObjectID
from sys.procedures p
	inner join sys.schemas s on s.schema_id = p.schema_id
where not (s.name = N''z'' and p.name = N''usp_ExecuteProcedures'')
	and exists (select 1 from #ExecuteProceduresFilters f where f.FilterType = ''IncludeSchema'' and s.name like f.Pattern collate catalog_default escape N''!'')
	and exists (select 1 from #ExecuteProceduresFilters f where f.FilterType = ''IncludeProcedure'' and p.name like f.Pattern collate catalog_default escape N''!'')
	and not exists (select 1 from #ExecuteProceduresFilters f where f.FilterType = ''ExcludeSchema'' and s.name like f.Pattern collate catalog_default escape N''!'')
	and not exists (select 1 from #ExecuteProceduresFilters f where f.FilterType = ''ExcludeProcedure'' and p.name like f.Pattern collate catalog_default escape N''!'');',
			@ExistsSql nvarchar(max) = N'
select	@CurrentObjectID = p.object_id
from sys.procedures p
	inner join sys.schemas s on s.schema_id = p.schema_id
where s.name = @SchemaName collate catalog_default
	and p.name = @ProcedureName collate catalog_default;';

	begin try
		select	f.FilterType, trim(p.value) collate database_default Pattern
		into #ExecuteProceduresFilters
		from (values
			('IncludeDatabase', @DatabaseNames), ('ExcludeDatabase', @ExcludedDatabaseNames),
			('IncludeSchema', isnull(@SchemaNames, N'%')),
			('ExcludeSchema', @ExcludedSchemaNames), ('IncludeProcedure', @ProcedureNames), ('ExcludeProcedure', @ExcludedProcedureNames)
		) f(FilterType, Patterns)
			cross apply string_split(f.Patterns, N',') p
		where trim(p.value) <> N'';

		declare cDatabases cursor local forward_only static read_only for
			select	d.name
			from sys.databases d
			where d.state = 0 and has_dbaccess(d.name) = 1
				and ((@DatabaseNames is null and d.database_id = db_id())
					or exists (select 1 from #ExecuteProceduresFilters f where f.FilterType = 'IncludeDatabase' and d.name collate database_default like f.Pattern escape N'!'))
				and not exists (select 1 from #ExecuteProceduresFilters f where f.FilterType = 'ExcludeDatabase' and d.name collate database_default like f.Pattern escape N'!');
		open cDatabases;
		fetch next from cDatabases into @DatabaseName;
		while @@fetch_status = 0
		begin
			select	@DatabaseExecutor = quotename(@DatabaseName) + N'.sys.sp_executesql';
			insert @Procedures(DatabaseName, SchemaName, ProcedureName, ObjectID)
				exec @DatabaseExecutor @ListSql, N'@DatabaseName sysname', @DatabaseName = @DatabaseName;
			fetch next from cDatabases into @DatabaseName;
		end;
		close cDatabases;
		deallocate cDatabases;
	end try
	begin catch
		throw;
	end catch;

	declare cProcedures cursor local forward_only static read_only for
		select	p.DatabaseName, p.SchemaName, p.ProcedureName, p.ObjectID
		from @Procedures p
		order by p.DatabaseName, p.SchemaName, p.ProcedureName;
	open cProcedures;
	fetch next from cProcedures into @DatabaseName, @SchemaName, @ProcedureName, @ObjectID;
	while @@fetch_status = 0
	begin
		select	@Proc = quotename(@DatabaseName) + N'.' + quotename(@SchemaName) + N'.' + quotename(@ProcedureName), @SemaphoreSlot = 0;
		begin try
			-- The qualified name can now resolve to a replacement for the listed object.
			if len(@Proc) <= 517
				select	@CurrentObjectID = object_id(@Proc);
			else
			begin
				select	@DatabaseExecutor = quotename(@DatabaseName) + N'.sys.sp_executesql', @CurrentObjectID = null;
				exec @DatabaseExecutor @ExistsSql, N'@SchemaName sysname, @ProcedureName sysname, @CurrentObjectID int output',
					@SchemaName = @SchemaName, @ProcedureName = @ProcedureName, @CurrentObjectID = @CurrentObjectID output;
			end;
			if @CurrentObjectID is not null
			begin
				select	@SemaphoreName = concat(N'z.ExecuteProcedures:',
							case when db_id(@DatabaseName) = db_id() then N'' else @DatabaseName + N':' end,
							@CurrentObjectID);
				exec @SemaphoreSlot = z.usp_AcquireSemaphore @SemaphoreName = @SemaphoreName, @TotalCount = 1, @LockOwner = 'Session', @LockTimeout = 0;
				if @SemaphoreSlot > 0
				begin
					if len(@Proc) <= 517
						select	@CurrentObjectID = object_id(@Proc);
					else
					begin
						select	@CurrentObjectID = null;
						exec @DatabaseExecutor @ExistsSql, N'@SchemaName sysname, @ProcedureName sysname, @CurrentObjectID int output',
							@SchemaName = @SchemaName, @ProcedureName = @ProcedureName, @CurrentObjectID = @CurrentObjectID output;
					end;
					if @CurrentObjectID is not null
						exec @Proc;
				end;
			end;
		end try
		begin catch
			select	@Messages = concat(@Messages, nchar(13), nchar(10), N'Exception while executing ', @Proc, N':', nchar(13), nchar(10),
								z.fn_GetFullErrorMessage(), nchar(13), nchar(10));
			if @@trancount > 0
				rollback;
		end catch;
		if @SemaphoreSlot > 0
			exec z.usp_ReleaseSemaphore @SemaphoreName = @SemaphoreName, @SuppressException = 1, @Slot = @SemaphoreSlot, @LockOwner = 'Session';
		fetch next from cProcedures into @DatabaseName, @SchemaName, @ProcedureName, @ObjectID;
	end;
	close cProcedures;
	deallocate cProcedures;
	while @Messages <> N''
	begin
		print left(@Messages, 2000);
		select	@Messages = stuff(@Messages, 1, 2000, N'');
	end;
end;
