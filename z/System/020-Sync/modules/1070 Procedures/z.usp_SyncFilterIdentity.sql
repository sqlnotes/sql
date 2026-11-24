create or alter procedure z.usp_SyncFilterIdentity
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
	select @ShouldInitialize = 0

	declare @SQL nvarchar(max), @MaxValue sql_variant

	select @SQL = 'select top 1 @ToValue = $identity from ' + @SourceTable + ' order by $identity desc'
	exec sp_executesql @SQL, N'@ToValue sql_variant output', @MaxValue output

	select @FromValue = @ToValue
	if @FromValue is null
	begin
		select @ShouldInitialize = 1
	end
	select @ToValue = @MaxValue
end

go
