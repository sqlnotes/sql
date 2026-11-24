create or alter procedure z.usp_SyncCallBack(
    @ConfigID int,
    @BatchCount int,
    @RowsInBatch int,
    @TotalRows bigint,
    @BatchStartDate datetime2(7),
    @BatchEndDate datetime2(7),
    @CallBackProcedure nvarchar(200) =null
)
as
begin
    set nocount on
    if @RowsInBatch not in (-1, -2)
        begin
            if @CallBackProcedure is not null
                exec @CallBackProcedure @ConfigID = @ConfigID
            exec z.usp_UpdateSyncProgress @ConfigID = @ConfigID, @BatchCount = @BatchCount,
                 @RowsInBatch = @RowsInBatch, @TotalRows = @TotalRows, @BatchStartDate = @BatchStartDate,
                 @BatchEndDate = @BatchEndDate
        end

end


go
