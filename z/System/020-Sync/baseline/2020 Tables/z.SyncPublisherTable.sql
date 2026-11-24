if object_id('z.SyncPublisherTable', 'U') is null
begin
	create table z.SyncPublisherTable
	(
		PublisherID int not null,
		TableName nvarchar(200) not null,
		ConfigID int not null,
		RowVersion rowversion not null,
		constraint PK_z_SyncPublisherTable primary key clustered (PublisherID, TableName),
		index IX_z_SyncPublisherTable_RowVersion nonclustered (RowVersion),
		index IX_z_SyncPublisherTable_ConfigID unique nonclustered (ConfigID)
	);
end
go
