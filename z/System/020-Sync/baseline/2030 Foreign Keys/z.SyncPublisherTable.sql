if not exists (select * from sys.foreign_keys where parent_object_id = object_id('z.SyncPublisherTable') and name = 'FK_z_SyncPublisherTable_SyncPublisher_PublisherID')
	alter table z.SyncPublisherTable add constraint FK_z_SyncPublisherTable_SyncPublisher_PublisherID foreign key (PublisherID) references z.SyncPublisher (PublisherID);
if not exists (select * from sys.foreign_keys where parent_object_id = object_id('z.SyncPublisherTable') and name = 'FK_z_SyncPublisherTable_SyncConfig_ConfigID')
	alter table z.SyncPublisherTable add constraint FK_z_SyncPublisherTable_SyncConfig_ConfigID foreign key (ConfigID) references z.SyncConfig (ConfigID);
go
