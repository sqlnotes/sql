if not exists (select * from sys.foreign_keys where parent_object_id = object_id('z.SyncPublisherInitializationScript') and name = 'FK_z_SyncPublisherInitializationScript_SyncPublisher_PublisherID')
	alter table z.SyncPublisherInitializationScript add constraint FK_z_SyncPublisherInitializationScript_SyncPublisher_PublisherID foreign key (PublisherID) references z.SyncPublisher (PublisherID);
if not exists (select * from sys.foreign_keys where parent_object_id = object_id('z.SyncPublisherInitializationScript') and name = 'FK_z_SyncPublisherInitializationScript_SyncConfig_ConfigID')
	alter table z.SyncPublisherInitializationScript add constraint FK_z_SyncPublisherInitializationScript_SyncConfig_ConfigID foreign key (ConfigID) references z.SyncConfig (ConfigID);
go
