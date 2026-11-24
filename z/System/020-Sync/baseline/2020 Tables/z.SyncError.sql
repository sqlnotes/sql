if object_id('z.SyncError', 'U') is null
begin
	create table z.SyncError
	(
		ConfigID int not null,
		FirstErrorDate datetime2(7) not null,
		LastErrorDate datetime2(7) not null,
		ErrorCount int not null,
		LastError varchar(max) not null,
		ResolvedDate datetime2(7),
		RowVersion rowversion not null,
		constraint PK_z_SyncError primary key clustered (ConfigID),
		constraint CK_z_SyncError_ErrorCount check ([ErrorCount]>=(1))
	);
end
go
