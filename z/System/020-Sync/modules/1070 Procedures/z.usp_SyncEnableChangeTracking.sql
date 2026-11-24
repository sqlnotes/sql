create or alter procedure z.usp_SyncEnableChangeTracking
(
	@ServerName nvarchar(128),
	@DatabaseName nvarchar(128),
	@TableName nvarchar(256),
	@SQL nvarchar(max) = null output,
	@SQL1 nvarchar(max) = null output,
	@ExecuteSQL bit = 1
)
as
begin
	set nocount, xact_abort on

	exec z.usp_SyncEnableChangeTrackingOnDB @ServerName = @ServerName, @DatabaseName = @DatabaseName, @SQL = @SQL output, @ExecuteSQL = @ExecuteSQL

	select @SQL1 = ' declare @SQL nvarchar(max), @TableName nvarchar(200)= '+quotename(@TableName, '''')+'
	if not exists(select * from sys.change_tracking_tables where object_id = object_id(@TableName))
	begin
		select @SQL = ''declare @SQL nvarchar(max)
select @SQL = ''''alter table ''''+quotename(schema_name(schema_id))+''''.''''+quotename(name)+'''' enable change_tracking''''
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
	if @ExecuteSQL = 1
	begin
		exec z.usp_SyncExecuteSQL @ServerName, @DatabaseName, @SQL1
	end
end

go
