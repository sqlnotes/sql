if object_id('z.SystemHealthEvent') is null
begin
	create table z.SystemHealthEvent
	(
		EventDateUTC datetime not null,
		EventName nvarchar(128) not null,
		EventHash uniqueidentifier not null,
		EventBody xml not null,
		constraint PK_z_SystemHealthEvent primary key(EventDateUTC, EventName, EventHash) with (data_compression = page) on PS_SchemaZPartitionGenericDateTime(EventDateUTC)
	) on PS_SchemaZPartitionGenericDateTime(EventDateUTC)
end
