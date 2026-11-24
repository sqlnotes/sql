create or alter procedure z.usp_SyncFilterChangeDataCapture
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
    declare @MaxValue binary(10), @MinValue binary(10), @CaptureInstance nvarchar(128) = 'SchemaZSync_' + object_schema_name(object_id(@SourceTable)) + '_' + object_name(object_id(@SourceTable))

    select  @ShouldInitialize = 0,
            @MinValue = sys.fn_cdc_increment_lsn(cast(@ToValue as binary(10))),
            @MaxValue = sys.fn_cdc_get_max_lsn()

    select @MinValue = case when start_lsn > @MinValue then start_lsn else @MinValue end
    from cdc.change_tables
    where source_object_id = object_id(@SourceTable)
        and capture_instance = @CaptureInstance
    if @@rowcount = 0
    begin
        raiserror('Count not find Capture Instance %s on table %s.', 16, 1, @CaptureInstance, @SourceTable)
        return
    end
    select @FromValue = @MinValue, @ToValue = @MaxValue
    if @FromValue is null
    begin
        select @ShouldInitialize = 1, @ToValue = @MaxValue
    end
    else
    begin
        if @FromValue > @ToValue
            select @FromValue = @ToValue
    end
end


go
