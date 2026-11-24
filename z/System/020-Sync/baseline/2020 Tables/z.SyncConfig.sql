if object_id('z.SyncConfig', 'U') is null
begin
	create table z.SyncConfig
	(
		ConfigID int identity(1,1) not null,
		Name varchar(128) not null,
		InitializationQuery nvarchar(max),
		FilterProcedure nvarchar(256) not null,
		FilteredQuery nvarchar(max) not null,
		SourceTable nvarchar(256),
		FilterField nvarchar(128),
		TargetObject nvarchar(256) not null,
		TargetObjectFieldList nvarchar(max) not null,
		BatchSize int not null constraint DF_z_SyncConfig_BatchSize default ((1500)),
		IsActive bit not null constraint DF_z_SyncConfig_IsActive default ((1)),
		RowVersion rowversion not null,
		CallBackProcedure nvarchar(200),
		SourceType varchar(20) not null constraint DF_z_SyncConfig_SourceType default ('DATABASE'),
		Concurrency int not null constraint DF_z_SyncConfig_Concurrency default ((1)),
		constraint PK_z_SyncConfig primary key clustered (ConfigID),
		index IX_z_SyncConfig_RowVersion nonclustered (RowVersion),
		constraint UQ_z_SyncConfig_Name unique nonclustered (Name),
		constraint CK_z_SyncConfig_FilterProcedure check (object_id([FilterProcedure]) is not null)
	);
end
go
