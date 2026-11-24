if object_id('z.SyncConnection', 'U') is null
begin
	create table z.SyncConnection
	(
		ConnectionID int identity(1,1) not null,
		Name nvarchar(128) not null,
		ConnectionString nvarchar(max) not null,
		Description nvarchar(max),
		constraint PK_z_SyncConnection primary key clustered (ConnectionID),
		constraint UQ_z_SyncConnection_Name unique nonclustered (Name),
		constraint CK_z_SyncConnection_Name check (datalength(Name) = datalength(trim(Name)) and Name <> ''),
		constraint CK_z_SyncConnection_ConnectionString check (len(trim(ConnectionString)) > 0)
	);
end
go
