create or alter procedure z.usp_SyncDisableChangeTrackingOnDB
(
	@ServerName nvarchar(128) = null,
	@DatabaseName nvarchar(128) = null
)
as
begin
	set nocount on
	declare @SQL nvarchar(max)
	select @SQL = 'declare @SQL nvarchar(max)
	if exists(select * from sys.change_tracking_databases where database_id = db_id())
	begin
		declare c cursor local for
			select quotename(object_schema_name(object_id)) + ''.'' + quotename(object_name(object_id))
			from sys.change_tracking_tables
		open c
		fetch next from c into @SQL
		while @@fetch_status = 0
		begin
			exec z.usp_SyncDisableChangeTracking null, null, @SQL
			fetch next from c into @SQL
		end
		close c
		deallocate c
		select @SQL = ''alter database ''+quotename(db_name())+'' set change_tracking = off;''
		exec(@SQL)
	end
	'

	exec z.usp_SyncExecuteSQL @ServerName, @DatabaseName, @SQL
end


go
