create or alter procedure z.usp_SyncFilterBack5MinuteForward1Hour
(
	@ConfigID int,
	@FromValue sql_variant output,
	@ToValue sql_variant output,
	@FromValueAdjusted sql_variant output,
	@ToValueAdjusted sql_variant output,
	@ShouldInitialize bit output,
	@SourceTable nvarchar(256) = null,
	@FilterField nvarchar(128) = null
)
as
begin
	set nocount on
	declare @MaxValue datetime, @SQL nvarchar(max)
	select @ShouldInitialize = 0

	select @SQL = 'select top 1 @MaxValue = ' + @FilterField + ' from ' + @SourceTable + ' order by ' + @FilterField + ' desc'
	exec sp_executesql @SQL, N'@MaxValue datetime output', @MaxValue output

	select @FromValue = @ToValue
	if @FromValue is null
	begin
		select @ShouldInitialize = 1
	end
	select @ToValue = @MaxValue
	select	@FromValueAdjusted = dateadd(minute, -5, cast(@FromValue as datetime)),
			@ToValueAdjusted = dateadd(hour, 1, cast(@ToValue as datetime))
end

go
