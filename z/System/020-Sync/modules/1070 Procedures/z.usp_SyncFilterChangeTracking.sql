create or alter procedure z.usp_SyncFilterChangeTracking
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
	declare @MaxValue bigint = cast(isnull(change_tracking_current_version(), 0) as bigint),
			@MinValue bigint = isnull(change_tracking_min_valid_version(object_id(@SourceTable)), 0)

	select @FromValue = @ToValue
	if @FromValue is null
	begin
		select @ShouldInitialize = 1
		select @ToValue = @MaxValue
	end
	else
	begin
		select	@ToValue = @MaxValue, @FromValue = case when cast(@FromValue as bigint) >= @MinValue then @FromValue else @MinValue end
	end
end


go
