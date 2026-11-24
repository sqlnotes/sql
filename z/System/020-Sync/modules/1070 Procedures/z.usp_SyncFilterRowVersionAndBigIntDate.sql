create or alter procedure z.usp_SyncFilterRowVersionAndBigIntDate
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

	declare @MinActiveRowVersion binary(8), @DateFrom datetime, @DateTo Datetime
	select @MinActiveRowVersion = min_active_rowversion()

	select @MinActiveRowVersion = case when @MinActiveRowVersion = 0x8000000000000000 then 0x7FFFFFFFFFFFFFFF else cast(@MinActiveRowVersion as bigint) - 1 end

	select @FromValue = @ToValue, @ToValueAdjusted = @FromValueAdjusted
	if @FromValue is null
	begin
		select @ShouldInitialize = 1, @FromValueAdjusted = null, @ToValueAdjusted = null
	end
	select @ToValue = @MinActiveRowVersion

	if @FromValueAdjusted is null
	begin
		select	@DateTo = dateadd(hour, 4 + datediff(hour, cast(cast(getdate() as date) as datetime), getdate()), cast(cast(getdate() as date) as datetime))
		select  @DateFrom = dateadd(hour, -1, @DateTo)
	end
	else
	begin
		select @ToValueAdjusted = @FromValueAdjusted

		select	@DateTo = dateadd(second, x0.seconds % 60, dateadd(minute, cast(x0.seconds / 60 as int), '1900-01-01'))
		from (select cast(@ToValueAdjusted as bigint)/268435456 as seconds) x0

		select  @DateFrom =  case when @DateTo <= '2020-01-01' then @DateFrom else dateadd(hour, -1, @DateTo) end
	end
	select	@FromValueAdjusted = datediff_big(second, '1900-01-01', @DateFrom) * 268435456,
			@ToValueAdjusted = datediff_big(second, '1900-01-01', @DateTo) * 268435456
end

go
