if object_id('z.SyncProgressPartition', 'U') is null
begin
	create table z.SyncProgressPartition
	(
		ConfigID int not null,
		Partition int not null,
		NextOffset bigint not null,
		UpdatedDate datetime2(7) not null constraint DF_z_SyncProgressPartition_UpdatedDate default (sysdatetime()),
		RowVersion rowversion not null,
		constraint PK_z_SyncProgressPartition primary key clustered (ConfigID, Partition),
		index IX_z_SyncProgressPartition_RowVersion nonclustered (RowVersion)
	);
end
go
