if not exists (select * from sys.foreign_keys where parent_object_id = object_id('z.SyncPublisher') and name = 'FK_z_SyncPublisher_SyncConnection_TargetConnectionID')
	alter table z.SyncPublisher add constraint FK_z_SyncPublisher_SyncConnection_TargetConnectionID foreign key (TargetConnectionID) references z.SyncConnection (ConnectionID);
if not exists (select * from sys.foreign_keys where parent_object_id = object_id('z.SyncPublisher') and name = 'FK_z_SyncPublisher_SyncConnection_SourceConnectionID')
	alter table z.SyncPublisher add constraint FK_z_SyncPublisher_SyncConnection_SourceConnectionID foreign key (SourceConnectionID) references z.SyncConnection (ConnectionID);
if not exists (select * from sys.foreign_keys where parent_object_id = object_id('z.SyncPublisher') and name = 'FK_z_SyncPublisher_SyncConnection_FilterConnectionID')
	alter table z.SyncPublisher add constraint FK_z_SyncPublisher_SyncConnection_FilterConnectionID foreign key (FilterConnectionID) references z.SyncConnection (ConnectionID);
go
