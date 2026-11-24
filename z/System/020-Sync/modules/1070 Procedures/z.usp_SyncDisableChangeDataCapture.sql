create or alter procedure z.usp_SyncDisableChangeDataCapture
(
	@ServerName nvarchar(128) = null,
	@DatabaseName nvarchar(128) = null,
	@TableName nvarchar(256),
	@CaptureInstancePrefix nvarchar(256) = 'SchemaZSync'
)
as
begin
	set nocount, xact_abort on
	declare @SQL nvarchar(max)

	exec z.usp_SyncEnableChangeDataCaptureOnDB @ServerName, @DatabaseName

	exec z.usp_SyncExecuteSQL @ServerName, @DatabaseName, @SQL
	select @SQL = '
	if not exists(select * from sys.databases where name = db_name() and is_cdc_enabled = 1)
		return

	declare @TableName nvarchar(256) = ' + quotename(@TableName, '''') + ', @CaptureInstancePrefix nvarchar(256) = ' + isnull(quotename(@CaptureInstancePrefix, ''''), 'null') + '
	declare @CaptureInstance nvarchar(256), @SchemaName sysname = object_schema_name(object_id(@TableName)), @ObjectName sysname = object_name(object_id(@TableName))
	select @CaptureInstance = @CaptureInstancePrefix + ''_'' + @SchemaName + ''_'' + @ObjectName
	if @ObjectName is null
	begin
		raiserror(''Invalid table name %s.'', 16, 1, @TableName)
		return
	end
	if @CaptureInstance is null and @CaptureInstancePrefix is not null
	begin
		raiserror(''Invalid Capture Instance name'', 16, 1)
		return
	end

	if not exists(select * from cdc.change_tables where source_object_id = object_id(@TableName))
		return
	if @CaptureInstance is null
	begin
		exec sys.sp_cdc_disable_table @source_schema =  @SchemaName, @source_name = @ObjectName, @capture_instance = ''all''
		return;
	end
	if exists(select * from cdc.change_tables where capture_instance = @CaptureInstance)
	begin
		exec sys.sp_cdc_disable_table @source_schema =  @SchemaName, @source_name = @ObjectName, @capture_instance = @CaptureInstance
	end

	'
	exec z.usp_SyncExecuteSQL @ServerName, @DatabaseName, @SQL
end


go
