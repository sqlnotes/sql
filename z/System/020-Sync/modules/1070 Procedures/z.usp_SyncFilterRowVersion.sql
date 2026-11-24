create or alter procedure z.usp_SyncFilterRowVersion
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

	declare @MinActiveRowVersion binary(8) = min_active_rowversion()

	select @MinActiveRowVersion = case when @MinActiveRowVersion = 0x8000000000000000 then 0x7FFFFFFFFFFFFFFF else cast(@MinActiveRowVersion as bigint) - 1 end

	select @FromValue = @ToValue
	if @FromValue is null
	begin
		select @ShouldInitialize = 1
	end
	select @ToValue = @MinActiveRowVersion
end

go
