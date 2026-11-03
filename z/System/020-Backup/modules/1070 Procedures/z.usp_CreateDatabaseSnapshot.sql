/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/020-Backup/modules/1070%20Procedures/z.usp_CreateDatabaseSnapshot.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/020-Backup/docs/reference/z.usp_CreateDatabaseSnapshot.md

Creates a database snapshot using the source database's data-file definitions.
*/
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
		throw 50000, 'Could not find source database.', 1;
	end
	select @DatabaseSnapshotName = isnull(@DatabaseSnapshotName, @SourceDatabaseName + '_Snapshot')
	if db_id(@DatabaseSnapshotName) is not null
	begin
		declare @Error nvarchar(2048) = replace(formatmessage(N'Database %s already exists.', @DatabaseSnapshotName), N'%', N'%%');
		throw 50000, @Error, 1;
	end
	
	declare @SQL nvarchar(max), @Proc sysname = quotename(@SourceDatabaseName)+'..sp_executesql'
	declare @t table(name sysname, physical_name sysname, i int identity(1,1))
	insert into @t
		exec @Proc N'select name, physical_name from sys.database_files where type = 0'
	if @@rowcount = 0
	begin
		throw 50000, 'Unknown error.', 1;
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
