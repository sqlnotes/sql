if not exists (select * from sys.foreign_keys where parent_object_id = object_id('z.SyncError') and name = 'FK_z_SyncError_SyncConfig_ConfigID')
	alter table z.SyncError add constraint FK_z_SyncError_SyncConfig_ConfigID foreign key (ConfigID) references z.SyncConfig (ConfigID) on delete cascade;
go
