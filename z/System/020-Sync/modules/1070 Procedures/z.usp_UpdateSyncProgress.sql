create or alter procedure z.usp_UpdateSyncProgress
(
    @ConfigID int = null,
    @FromValue sql_variant = null,
    @ToValue sql_variant = null,
    @FromValueAdjusted sql_variant = null,
    @ToValueAdjusted sql_variant = null,

    @BatchCount int = null,
    @RowsInBatch int = null,
    @TotalRows bigint = null,

    @BatchStartDate datetime2(7) = null,
    @BatchEndDate datetime2(7) = null,

    @StartDate datetime2(7) = null,
    @EndDate datetime2(7) = null,

    @Error varchar(max) = null
)
as
begin
    set nocount on
	if exists(select * from z.v_SyncProgress where ConfigID = @ConfigID and NeedInitialization = 0)
	begin
		delete z.SyncPublisherInitializationScript where ConfigID = @ConfigID
	end
    if not exists(select* from z.SyncProgress where ConfigID = @ConfigID)
        begin
            insert into z.SyncProgress(ConfigID, StartDate, SessionID, ApplicationName)
            values(@ConfigID, isnull(@StartDate, sysdatetime()), @@spid, app_name())
        end
    if @StartDate is not null
        begin
            update z.SyncProgress
            set StartDate = @StartDate,
                EndDate = null,
                Error = null,
                SessionID = @@spid,
                ApplicationName = app_name(),
                LoginName = system_user,
                SyncHistoryID = null,
                BatchCount = null,
                RowsInBatch = null,
                TotalRows = null,
                BatchStartDate = null,
                BatchEndDate = null
            where ConfigID = @ConfigID
        end
    update z.SyncProgress
    set FromValue = case
						when @Error is null then
							case when @FromValue is null then FromValue else @FromValue end
						else FromValue
					end,
        ToValue = case
					when @Error is null then
						case when @ToValue is null then iif(@EndDate is null, ToValue, isnull(@FromValue, ToValue)) else @ToValue end
					else ToValue
				end,
        FromValueAdjusted = case
								when @Error is null then
									case when @FromValueAdjusted is null then FromValueAdjusted else @FromValueAdjusted end
								else FromValueAdjusted
							end,
        ToValueAdjusted = case
							when @Error is null then
								case when @ToValueAdjusted is null then iif(@EndDate is null, ToValueAdjusted, isnull(@FromValueAdjusted, ToValueAdjusted)) else @ToValueAdjusted end
							else ToValueAdjusted
						end,
        SessionID = @@spid,
        BatchCount = case when @BatchCount is null then BatchCount else @BatchCount end,
        RowsInBatch = case when @RowsInBatch is null then RowsInBatch else @RowsInBatch end,
        TotalRows = case when @TotalRows is null then TotalRows else @TotalRows end,
        BatchStartDate = case when @BatchStartDate is null then BatchStartDate else @BatchStartDate end,
        BatchEndDate = case when @BatchEndDate is null then BatchEndDate else @BatchEndDate end,
        EndDate = case when @EndDate is null then EndDate else sysdatetime()  end,
        Error = case when @Error is null then Error else @Error end,
        SyncHistoryID = null,
        ApplicationName = app_name(),
        LoginName = system_user
    where ConfigID = @ConfigID
    if @Error is not null
    begin
        merge z.SyncError t
        using (select ConfigID = @ConfigID) s on s.ConfigID = t.ConfigID
        when matched then
            update set t.FirstErrorDate = iif(t.ResolvedDate is null, t.FirstErrorDate, sysdatetime()), t.LastErrorDate = sysdatetime(),
                t.ErrorCount = iif(t.ResolvedDate is null, t.ErrorCount + 1, 1), t.LastError = @Error, t.ResolvedDate = null
        when not matched then insert (ConfigID, FirstErrorDate, LastErrorDate, ErrorCount, LastError) values (@ConfigID, sysdatetime(), sysdatetime(), 1, @Error);
    end
    else if @EndDate is not null
    begin
        update z.SyncError set ResolvedDate = sysdatetime() where ConfigID = @ConfigID and ResolvedDate is null
    end
    if @EndDate is null
        return
    declare @ReplicationHistoryID bigint
    if @EndDate is not null and @Error is null and exists(select * from z.SyncProgress where ConfigID = @ConfigID and TotalRows > 0)
        begin
            insert into z.SyncHistory(ConfigID, FromValue, ToValue, FromValueAdjusted, ToValueAdjusted, BatchCount, TotalRows, StartDate, EndDate, ApplicationName, LoginName)
            select ConfigID, FromValue, ToValue, FromValueAdjusted, ToValueAdjusted,BatchCount, TotalRows, StartDate, EndDate, ApplicationName, LoginName
            from z.SyncProgress
            where ConfigID = @ConfigID
            select @ReplicationHistoryID = scope_identity()
            update z.SyncProgress
            set SyncHistoryID = @ReplicationHistoryID
            where ConfigID = @ConfigID
        end
end


go
