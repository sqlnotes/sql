if not exists (select * from sys.foreign_keys where parent_object_id = object_id('z.SyncProgress') and name = 'FK_z_SyncProgress_SyncConfig_ConfigID')
	alter table z.SyncProgress add constraint FK_z_SyncProgress_SyncConfig_ConfigID foreign key (ConfigID) references z.SyncConfig (ConfigID);
go
