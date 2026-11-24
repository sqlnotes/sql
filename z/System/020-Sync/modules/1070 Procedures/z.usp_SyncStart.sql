create or alter procedure z.usp_SyncStart
(
	@ConfigID int,
	@SQL nvarchar(max) output,
	@SQL1 nvarchar(max) output
)
as
begin
	set nocount on
	declare @FilterProcedure nvarchar(256), @SourceTable nvarchar(256), @Date datetime2(7) = sysdatetime(),
			@ExecuteSQL bit
	select	@ConfigID = c.ConfigID, @FilterProcedure = c.FilterProcedure,
			@SourceTable = quotename(object_schema_name(object_id(c.SourceTable))) + '.' + quotename(object_name(object_id(c.SourceTable))),
			@ExecuteSQL = case when p.SourceConnectionID is null and p.UseReadOnlyAGReplica = 0 then 1 else 0 end
	from z.SyncConfig c
		left join z.SyncPublisherTable t on t.ConfigID = c.ConfigID
		left join z.SyncPublisher p on p.PublisherID = t.PublisherID
	where c.ConfigID = @ConfigID
		and c.IsActive = 1
	if @@rowcount = 0
	begin
		raiserror('Could not find an active Sync config %i', 16, 1, @ConfigID)
		return
	end

	exec z.usp_UpdateSyncProgress @ConfigID = @ConfigID, @StartDate = @Date

	if @FilterProcedure like '%ChangeTracking%' and @SourceTable is not null
	begin
		exec z.usp_SyncEnableChangeTracking @ServerName = null, @DatabaseName = null, @TableName = @SourceTable, @SQL = @SQL output, @SQL1 = @SQL1 output, @ExecuteSQL = @ExecuteSQL
	end
	else if @FilterProcedure like '%ChangeDataCapture%' and @SourceTable is not null
	begin
		exec z.usp_SyncEnableChangeDataCapture @ServerName = null, @DatabaseName = null, @TableName = @SourceTable, @SQL = @SQL output, @SQL1 = @SQL1 output, @ExecuteSQL = @ExecuteSQL
	end
	if @ExecuteSQL = 1
	begin
		select @SQL = null, @SQL1 = null
	end
end


go
