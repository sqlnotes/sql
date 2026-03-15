--drop table z.AsyncConfiguration
if object_id('z.AsyncConfiguration') is null
begin
	create table z.AsyncConfiguration
	(
		ConfigurationID int not null identity(1,1),
		Name nvarchar(128) not null,
		Description nvarchar(1000),
		InterfaceViewName nvarchar(200) not null,
		NumberOfInternalWorkers int not null constraint DF_z_AsyncConfiguration_NumberOfInternalWorkers default(1),
		IsActive bit not null constraint DF_z_AsyncConfiguration_IsActive default(0),
		RowVersion rowversion not null,
		constraint PK_z_AsyncConfiguration primary key(ConfigurationID),
		index IX_z_AsyncConfiguration_Name unique (Name),
		index IX_z_AsyncConfiguration_RowVersion (RowVersion),
		index IX_z_AsyncConfiguration_InterfaceViewName unique (InterfaceViewName),
		constraint CK_z_AsyncConfiguration_InterfaceViewName check(isnull(left(object_name(object_id(InterfaceViewName, 'V')), 7), '') = 'v_Async' )
	)
end
