create or alter procedure z.usp_CreateSyncPublisher
(
	@PublisherName nvarchar(128),
	@PublisherID int = null output,
	@TargetConnectionID	int = null,
	@SourceConnectionID	int = null,
	@UseReadOnlyAGReplica bit = 0,
	@FilterConnectionID int = null,
	@MaxInitializationTasks int = null,
	@MaxIncrementalTasks int = null,
	@SyncIntervalMS bigint = null,
	@ETLCodebase nvarchar(256) = null,
	@IsActive bit = 0
)
as
begin
	set nocount on
	select @PublisherID = PublisherID
	from z.SyncPublisher
	where Name = @PublisherName
	if @@rowcount = 0
	begin
		insert into z.SyncPublisher(Name, TargetConnectionID, IsActive, SourceConnectionID, UseReadOnlyAGReplica, FilterConnectionID, MaxInitializationTasks, MaxIncrementalTasks, SyncIntervalMS, ETLCodebase)
			values(@PublisherName, @TargetConnectionID, @IsActive, @SourceConnectionID, @UseReadOnlyAGReplica, @FilterConnectionID, @MaxInitializationTasks, @MaxIncrementalTasks, @SyncIntervalMS, @ETLCodebase)
		select @PublisherID = scope_identity()
	end
end


go
