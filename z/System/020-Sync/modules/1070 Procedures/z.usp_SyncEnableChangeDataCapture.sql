create or alter procedure z.usp_SyncEnableChangeDataCapture
(
	@ServerName nvarchar(128) = null,
	@DatabaseName nvarchar(128) = null,
	@TableName nvarchar(256),
	@CaptureInstancePrefix nvarchar(256) = 'SchemaZSync',
	@ColumnList nvarchar(max) = null,
	@IndexName nvarchar(128) = null,
	@SQL nvarchar(max) = null output,
	@SQL1 nvarchar(max) = null output,
	@ExecuteSQL bit = 1
)
as
begin
	set nocount, xact_abort on

	exec z.usp_SyncEnableChangeDataCaptureOnDB @ServerName = @ServerName, @DatabaseName = @DatabaseName, @SQL = @SQL output, @ExecuteSQL = @ExecuteSQL
	select @SQL1 = '
	declare @TableName nvarchar(256) = ' + quotename(@TableName, '''') + ', @CaptureInstancePrefix nvarchar(256) = ' + iif(@CaptureInstancePrefix is null, 'null', '''' + replace(@CaptureInstancePrefix, '''', '''''') + '''') + '
	declare @CaptureInstance nvarchar(256), @SchemaName sysname = object_schema_name(object_id(@TableName)), @ObjectName sysname = object_name(object_id(@TableName))
	select @CaptureInstance = isnull(nullif(@CaptureInstancePrefix, '''') + ''_'', '''') + @SchemaName + ''_'' + @ObjectName
	if @ObjectName is null
	begin
		raiserror(''Invalid table name %s.'', 16, 1, @TableName)
		return
	end
	if @CaptureInstance is null
	begin
		raiserror(''Invalid Capture Instance name'', 16, 1)
		return
	end
	if not exists(select * from cdc.change_tables where capture_instance = @CaptureInstance)
	begin
		exec sys.sp_cdc_enable_table @source_schema =  @SchemaName, @source_name = @ObjectName, @capture_instance = @CaptureInstance, @supports_net_changes =  1,  @role_name = ''public'', @index_name =  ' + case when @IndexName is null then 'null' else quotename(@IndexName, '''') end + ', @captured_column_list = ' + iif(@ColumnList is null, 'null', '''' + replace(@ColumnList, '''', '''''') + '''') + ', @filegroup_name = null, @allow_partition_switch =  1;
	end
	'
	if @ExecuteSQL = 1
	begin
		exec z.usp_SyncExecuteSQL @ServerName, @DatabaseName, @SQL1
	end
end


go
