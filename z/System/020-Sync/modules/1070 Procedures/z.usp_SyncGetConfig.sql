create or alter procedure z.usp_SyncGetConfig
(
	@ConfigID int
)
as
begin
	set nocount on
	declare @InitializationQuery nvarchar(max), @FilterProcedure nvarchar(max), @FilteredQuery nvarchar(max),
			@SourceTable nvarchar(256), @FilterField nvarchar(128), @TargetObject nvarchar(256), @BatchSize int, @TargetObjectFieldList nvarchar(max),
			@ConnectionString nvarchar(max), @FromValue sql_variant, @ToValue sql_variant, @FromValueAdjusted sql_variant, @ToValueAdjusted sql_variant,
			@Date datetime2(7) = sysdatetime(), @SourceConnectionString nvarchar(max), @CallBackProcedure nvarchar(200),
			@UseReadOnlyAGReplica bit, @StartPosition int, @PublisherID int,
		@FilterConnectionString nvarchar(max),
		@SourceType varchar(20),
		@Concurrency int
	select	@ConfigID = c.ConfigID, @InitializationQuery = c.InitializationQuery, @FilterProcedure = c.FilterProcedure,
			@FilteredQuery = c.FilteredQuery, @SourceTable = c.SourceTable, @FilterField = c.FilterField,
			@TargetObject = c.TargetObject, @BatchSize = c.BatchSize, @TargetObjectFieldList = c.TargetObjectFieldList,
			@ConnectionString = tc.ConnectionString, @SourceConnectionString = sc.ConnectionString,
			@UseReadOnlyAGReplica = p.UseReadOnlyAGReplica, @FilterConnectionString = fc.ConnectionString,
			@SourceType = c.SourceType, @Concurrency = c.Concurrency
	from z.SyncConfig c
		inner join z.SyncPublisherTable t on c.ConfigID = t.ConfigID
		inner join z.SyncPublisher p on p.PublisherID = t.PublisherID
		left join z.SyncConnection tc on tc.ConnectionID = p.TargetConnectionID
		left join z.SyncConnection sc on sc.ConnectionID = p.SourceConnectionID
		left join z.SyncConnection fc on fc.ConnectionID = p.FilterConnectionID
	where c.ConfigID = @ConfigID
		and c.IsActive = 1 and p.IsActive = 1
	if @@rowcount = 0 or @TargetObjectFieldList is null
	begin
		raiserror('Could not find ETL config %d or TargetObjectFieldList is empty.', 16, 1, @ConfigID)
		return;
	end
	select @PublisherID = t.PublisherID
	from z.SyncPublisherTable  t
	where t.ConfigID = @ConfigID

	select @FromValue = FromValue, @ToValue = ToValue,
		   @FromValueAdjusted = FromValueAdjusted, @ToValueAdjusted = ToValueAdjusted
	from z.SyncProgress
	where ConfigID = @ConfigID
	declare @FilterProcedureName nvarchar(max) = @FilterProcedure
	select @FilterProcedure = definition
	from sys.sql_modules
	where object_id = object_id(@FilterProcedure)
	if @@rowcount = 0 or @FilterProcedure is null
	begin
		raiserror('Could not find filtering procedure %s.', 16, 1, @FilterProcedure)
		return
	end
	select @StartPosition = charindex('begin', @FilterProcedure)
	select @FilterProcedure = cast('declare @ConfigID int, @FromValue sql_variant, @ToValue sql_variant, @FromValueAdjusted sql_variant, @ToValueAdjusted sql_variant, @ShouldInitialize bit, @SourceTable nvarchar(256) = null, @FilterField nvarchar(128) = null
select @ConfigID =?, @FromValue =?, @ToValue =?, @FromValueAdjusted =?, @ToValueAdjusted =?, @SourceTable =?, @FilterField =?
' as nvarchar(max)) + substring(@FilterProcedure, @StartPosition, len(@FilterProcedure) - charindex('dne', reverse(@FilterProcedure)) - @StartPosition + 2) + '
select @FromValue FromValue, @ToValue ToValue, @FromValueAdjusted FromValueAdjusted, @ToValueAdjusted ToValueAdjusted, @ShouldInitialize ShouldInitialize'

	select	@ConfigID as ConfigID, @ConnectionString as ConnectionString, @TargetObject TargetObject, @BatchSize as BatchSize,
			@FromValue as FromValue, @ToValue as ToValue, @FromValueAdjusted as FromValueAdjusted, @ToValueAdjusted as ToValueAdjusted, @SourceConnectionString as SourceConnectionString,
			@UseReadOnlyAGReplica as UseReadOnlyAGReplica, @FilterProcedure FilterProcedure, @SourceTable SourceTable, @FilterField FilterField,
			@InitializationQuery InitializationQuery, @FilteredQuery FilteredQuery, @PublisherID PublisherID, @FilterConnectionString FilterConnectionString,
			@SourceType SourceType, @Concurrency Concurrency, @FilterProcedureName FilterProcedureName
	select rtrim(ltrim(replace(replace(replace(replace(value, '[', ''), ']', ''), '"', ''), '"', ''))) FieldName
	from string_split(@TargetObjectFieldList, ',')
end

go
