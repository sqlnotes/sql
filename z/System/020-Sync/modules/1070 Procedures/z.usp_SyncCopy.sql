create or alter procedure z.usp_SyncCopy
(
	@ConfigID int,
	@SourceQuery nvarchar(max),
	@TargetTableName nvarchar(256),
	@TargetTableFieldList nvarchar(max) = null,
	@BatchSize int = 10000,
	@FromValue sql_variant = null,
	@FromValueAdjusted sql_variant = null,
	@ToValue sql_variant = null,
	@ToValueAdjusted sql_variant = null,
	@ConvertValueToDateType nvarchar(128) = 'sql_variant',
	@CallBackProcedure nvarchar(200) = null
)
as
begin
	set nocount, xact_abort on
	declare @SQL nvarchar(max), @Def nvarchar(max) = N'@ConfigID int,@FromValue sql_variant,@FromValueAdjusted sql_variant,@ToValue sql_variant,@ToValueAdjusted sql_variant, @CallBackProcedure nvarchar(200)'

	select @SQL = '
declare @F ' + @ConvertValueToDateType + ' = cast(@FromValue as ' + @ConvertValueToDateType + '), @FA ' + @ConvertValueToDateType + ' = cast(@FromValueAdjusted as ' + @ConvertValueToDateType + '), @T ' + @ConvertValueToDateType + ' = cast(@ToValue as ' + @ConvertValueToDateType + '), @TA ' + @ConvertValueToDateType + ' = cast(@ToValueAdjusted as ' + @ConvertValueToDateType + ');
declare @handle int, @RowCount int, @TotalRows bigint = 0, @BatchStartDate datetime2(7) = sysdatetime(), @BatchEndDate datetime2(7), @BatchCount int = 0, @rc int;
insert into ' + @TargetTableName + isnull('('+@TargetTableFieldList+')', '') + '
	exec sp_cursoropen @cursor = @handle output,@stmt = '''+replace(@SourceQuery, '''', '''''')+ ''', @scrollopt = 4112, @ccopt = 8193,@rowcount = @rc output, @paramdef = N''@ConfigID int,@FromValue ' + @ConvertValueToDateType + ',@FromValueAdjusted ' + @ConvertValueToDateType + ',@ToValue ' + @ConvertValueToDateType + ',@ToValueAdjusted ' + @ConvertValueToDateType + ''', @ConfigID = @ConfigID, @FromValue = @F, @FromValueAdjusted = @FA, @ToValue = @T, @ToValueAdjusted = @TA;
while(1=1)
begin
	select @BatchStartDate = sysdatetime()
	insert into ' + @TargetTableName + isnull('('+@TargetTableFieldList+')', '') + '
		exec sp_cursorfetch @handle, 2,  0, '+cast(@BatchSize as varchar(20))+';
	select @RowCount = isnull(isnull(nullif(@@rowcount, 0), cast(session_context (N''SyncRowCount'') as int)), 0)
	exec sp_set_session_context N''SyncRowCount'', null
	select @TotalRows = @TotalRows + @RowCount, @BatchCount = @BatchCount + 1, @BatchEndDate = sysdatetime()
	exec z.usp_SyncCallBack @ConfigID, @BatchCount, @RowCount, @TotalRows, @BatchStartDate, @BatchEndDate, @CallBackProcedure;
	if @RowCount < '+cast(@BatchSize as varchar(20))+'
		break;
end
exec sp_cursorclose @handle
'
	exec sp_executesql @SQL, @Def, @ConfigID, @FromValue, @FromValueAdjusted, @ToValue, @ToValueAdjusted, @CallBackProcedure

end

go
