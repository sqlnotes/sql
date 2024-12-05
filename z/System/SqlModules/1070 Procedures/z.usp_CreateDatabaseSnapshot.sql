create or alter procedure z.usp_CreateDatabaseSnapshot
(
	@SourceDatabaseName nvarchar(128) = null,
	@DatabaseSnapshotName nvarchar(128) = null
)
as
begin
	set xact_abort on
	select @SourceDatabaseName = db_name(db_id(isnull(@SourceDatabaseName, db_name())))
	if @SourceDatabaseName is null
	begin
		raiserror('Could not find source database.', 16, 1)
		return
	end
	select @DatabaseSnapshotName = isnull(@DatabaseSnapshotName, @SourceDatabaseName + '_Snapshot')
	if db_id(@DatabaseSnapshotName) is not null
	begin
		raiserror('Database %s already exists.', 16, 1, @DatabaseSnapshotName)
		return
	end
	
	declare @SQL nvarchar(max), @Proc sysname = quotename(@SourceDatabaseName)+'..sp_executesql'
	declare @t table(name sysname, physical_name sysname, i int identity(1,1))
	insert into @t
		exec @Proc N'select name, physical_name from sys.database_files where type = 0'
	if @@rowcount = 0
	begin
		raiserror('Unknown error.', 16, 1)
		return
	end

	select @SQL = 'create database '+ quotename(@DatabaseSnapshotName) + ' on '
		+ stuff(
					(
						select ', (name = '+quotename(name)+', filename = ''' + physical_name + '.' + replace(@DatabaseSnapshotName, ' ', '') + ''')'
						from @t
						order by i
						for xml path(''), type
					).value('.', 'nvarchar(max)')
				, 1, 2, '')
		+ ' as snapshot of '+quotename(@SourceDatabaseName)+' ;'
	exec(@SQL)
end
