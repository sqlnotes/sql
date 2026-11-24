if object_id('z.SyncPublisherInitializationScript', 'U') is null
begin
	create table z.SyncPublisherInitializationScript
	(
		PublisherID int not null,
		ConfigID int not null,
		ScriptOrder int not null,
		Script nvarchar(max) not null,
		RowVersion rowversion not null,
		constraint PK_z_SyncPublisherInitializationScript primary key clustered (PublisherID, ConfigID, ScriptOrder),
		index IX_z_SyncPublisherInitializationScript_RowVersion nonclustered (RowVersion),
		index IX_z_SyncPublisherInitializationScript_ConfigID nonclustered (ConfigID)
	);
end
go
