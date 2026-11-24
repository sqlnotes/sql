create or alter procedure z.usp_SyncDisableChangeTracking
(
	@ServerName nvarchar(128),
	@DatabaseName nvarchar(128),
	@TableName nvarchar(256)
)
as
begin
	set nocount, xact_abort on
	declare @SQL nvarchar(max)

	select @SQL = ' declare @SQL nvarchar(max), @TableName nvarchar(200)= '+quotename(@TableName, '''')+'
	if exists(select * from sys.change_tracking_tables where object_id = object_id(@TableName))
	begin
		select @SQL = '' set nocount on
declare @SQL nvarchar(max)
select @SQL = ''''alter table ''''+quotename(schema_name(schema_id))+''''.''''+quotename(name)+'''' disable change_tracking''''
from sys.tables
where object_id = object_id(@TableName)
if @@rowcount = 0
begin
	raiserror(''''Count not find table %s'''', 16, 1, @TableName)
	return
end

exec(@SQL)''
		select @SQL = ''exec sp_executesql N'''''' + replace(@SQL  , '''''''', '''''''''''') + '''''', N''''@TableName sysname'''', N'''''' + replace(@TableName, '''''''', '''''''''''') + ''''''''
		exec(@SQL)
	end'

	exec z.usp_SyncExecuteSQL @ServerName, @DatabaseName, @SQL
end

go
