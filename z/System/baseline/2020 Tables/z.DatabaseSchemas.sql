if object_id('z.DatabaseSchemas') is null
begin
	create table z.DatabaseSchemas
	(
		SchemaName nvarchar(128) not null,
		constraint PK_z_DatabaseSchemas primary key (SchemaName)
	)
end

