create or alter procedure z.usp_SyncOne (@FriendlyName varchar(128), @RaiseError bit = 1)
as
begin
	set nocount on
	declare @Date datetime2(7) = sysdatetime()
	begin try
		declare @ConfigID int, @InitializationQuery nvarchar(max), @FilterProcedure nvarchar(256), @FilteredQuery nvarchar(max),
				@SourceTable nvarchar(256), @FilterField nvarchar(128), @TargetObject nvarchar(256), @BatchSize int, @TargetObjectFieldList nvarchar(max),
				@Error nvarchar(max), @CallBackProcedure nvarchar(400),
				@FromValue sql_variant, @ToValue sql_variant, @FromValueAdjusted sql_variant, @ToValueAdjusted sql_variant, @ShouldInitialize bit

		select	@ConfigID = ConfigID, @InitializationQuery = InitializationQuery, @FilterProcedure = FilterProcedure,
				@FilteredQuery = FilteredQuery, @SourceTable = SourceTable, @FilterField = FilterField,
				@TargetObject = TargetObject, @BatchSize = BatchSize, @TargetObjectFieldList = TargetObjectFieldList,
				@CallBackProcedure = CallBackProcedure
		from z.SyncConfig
		where Name = @FriendlyName
			and IsActive = 1
		if @@rowcount = 0
		begin
			print 'Cannot found Sync config'
			return
		end

		exec z.usp_UpdateSyncProgress @ConfigID = @ConfigID, @StartDate = @Date

		if object_id(@FilterProcedure) is null
		begin
			raiserror('Filter procedure does not exists', 16, 1);
			return;
		end
		if @FilterProcedure like '%ChangeTracking%' and @SourceTable is not null
		begin
			exec z.usp_SyncEnableChangeTracking null, null, @SourceTable
		end
		else if @FilterProcedure like '%ChangeDataCapture%' and @SourceTable is not null
		begin
			exec z.usp_SyncEnableChangeDataCapture null, null, @SourceTable
		end

		select @FromValue = FromValue, @ToValue = ToValue, @FromValueAdjusted = FromValueAdjusted, @ToValueAdjusted = ToValueAdjusted
		from z.SyncProgress
		where ConfigID = @ConfigID

		exec @FilterProcedure @ConfigID, @FromValue output, @ToValue output, @FromValueAdjusted output, @ToValueAdjusted output, @ShouldInitialize output, @SourceTable, @FilterField

		declare @ConvertValueToDateType nvarchar(128) = 'sql_variant'
		if @FilterProcedure like '%ChangeTracking%'
			select @ConvertValueToDateType = 'bigint'

		exec sp_set_session_context N'IsSyncInitialization', @ShouldInitialize

		declare @SourceQuery nvarchar(max) = case when @ShouldInitialize = 1 then @InitializationQuery else @FilteredQuery end

		exec z.usp_SyncCopy
			@ConfigID = @ConfigID,
			@SourceQuery = @SourceQuery,
			@TargetTableName = @TargetObject,
			@TargetTableFieldList = @TargetObjectFieldList,
			@BatchSize = @BatchSize,
			@FromValue = @FromValue,
			@FromValueAdjusted = @FromValueAdjusted,
			@ToValue = @ToValue,
			@ToValueAdjusted = @ToValueAdjusted,
			@ConvertValueToDateType = @ConvertValueToDateType,
			@CallBackProcedure = @CallBackProcedure
		select @Date = sysdatetime();
		exec z.usp_UpdateSyncProgress @ConfigID = @ConfigID, @FromValue= @FromValue, @ToValue = @ToValue, @FromValueAdjusted = @FromValueAdjusted, @ToValueAdjusted = @ToValueAdjusted, @EndDate = @Date
		exec sp_set_session_context N'IsSyncInitialization', null
	end try
	begin catch
		exec sp_set_session_context N'IsSyncInitialization', null
		select @Error = error_message(), @Date = sysdatetime();
		exec z.usp_UpdateSyncProgress @ConfigID = @ConfigID, @Error = @Error, @EndDate = @Date;
		if @RaiseError = 1
			throw;
	end catch

end


go
