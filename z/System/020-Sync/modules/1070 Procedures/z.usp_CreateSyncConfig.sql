create or alter procedure z.usp_CreateSyncConfig
(
	@Name varchar(128),
	@InitializationQuery nvarchar(max),
	@FilterProcedure nvarchar(256),
	@FilteredQuery nvarchar(max),
	@SourceTable nvarchar(256),
	@FilterField nvarchar(128),
	@TargetObject nvarchar(256),
	@TargetObjectFieldList nvarchar(max),
	@BatchSize int,
	@IsActive bit,
	@ClearProgress int = 0,
	@ConfigID int = null output,
	@PublisherID int = null,
	@CallBackProcedure nvarchar(200) = null,
	@SourceType varchar(20) = 'DATABASE',
	@Concurrency int = 1
)
as
begin
	set nocount, xact_abort on
	update z.SyncConfig
		set @ClearProgress =	case
									when @ClearProgress in (0, 1) then @ClearProgress
									when @ClearProgress = 2 and TargetObjectFieldList <> @TargetObjectFieldList then 1
									when @ClearProgress = 2 and FilterProcedure <> @FilterProcedure then 1
									when @ClearProgress = 2 and TargetObject <> @TargetObject then 1
									else 0
								end,
			@ConfigID = ConfigID,
			Name = @Name,
			InitializationQuery = @InitializationQuery,
			FilterProcedure = @FilterProcedure,
			FilteredQuery = @FilteredQuery,
			SourceTable = @SourceTable,
			FilterField = @FilterField,
			TargetObject = @TargetObject,
			TargetObjectFieldList = @TargetObjectFieldList,
			BatchSize = @BatchSize,
			IsActive = @IsActive,
			CallBackProcedure = @CallBackProcedure,
			SourceType = @SourceType,
			Concurrency = @Concurrency
	where Name = @Name
	if @@rowcount = 0
	begin
		insert into z.SyncConfig(Name, InitializationQuery, FilterProcedure, FilteredQuery, SourceTable, FilterField, TargetObject, TargetObjectFieldList, BatchSize, IsActive, CallBackProcedure, SourceType, Concurrency)
			values(@Name, @InitializationQuery, @FilterProcedure, @FilteredQuery, @SourceTable, @FilterField, @TargetObject, @TargetObjectFieldList, @BatchSize, @IsActive, @CallBackProcedure, @SourceType, @Concurrency)
		select @ConfigID = scope_identity()
	end

	if @ClearProgress = 1
	begin
		delete z.SyncProgress where ConfigID = @ConfigID
		delete z.SyncProgressPartition where ConfigID = @ConfigID
		delete z.SyncHistory where ConfigID = @ConfigID
		delete z.SyncError where ConfigID = @ConfigID
	end

	if @PublisherID is not null
	begin
		merge z.SyncPublisherTable t
		using (select @PublisherID PublisherID, @ConfigID ConfigID) s on t.PublisherID = s.PublisherID and t.ConfigID = s.ConfigID
		when not matched then
			insert(PublisherID, TableName, ConfigID)
				values(@PublisherID, @Name, @ConfigID)
		when matched and t.TableName <> @Name then
			update set t.TableName = @Name
		;
	end
end


go
