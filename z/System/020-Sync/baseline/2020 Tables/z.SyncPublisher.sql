if object_id('z.SyncPublisher', 'U') is null
begin
	create table z.SyncPublisher
	(
		PublisherID int identity(1,1) not null,
		Name nvarchar(128) not null,
		Description nvarchar(max),
		TargetConnectionID int,
		Message nvarchar(max),
		IsActive bit constraint DF_z_SyncPublisher_IsActive default ((1)),
		RowVersion rowversion not null,
		ETLCodebase nvarchar(256),
		SourceConnectionID int,
		UseReadOnlyAGReplica bit not null constraint DF_z_SyncPublisher_UseReadOnlyAGReplica default ((0)),
		FilterConnectionID int,
		MaxInitializationTasks int,
		MaxIncrementalTasks int,
		SyncIntervalMS bigint,
		constraint PK_z_SyncPublisher primary key clustered (PublisherID),
		index IX_z_SyncPublisher_RowVersion nonclustered (RowVersion),
		index IX_z_SyncPublisher_Name unique nonclustered (Name),
		constraint CK_z_SyncPublisher_Name check (datalength([Name])=datalength(trim([Name])) and [Name]<>'')
	);
end
go
