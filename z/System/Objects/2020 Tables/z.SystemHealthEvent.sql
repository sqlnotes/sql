if object_id('z.SystemHealthEvent') is null
begin
	create table z.SystemHealthEvent
	(
		CollectSystemTime bigint not null,
		EventName nvarchar(128) not null,
		EventHash uniqueidentifier not null,
		EventBody xml not null,
		constraint PK_z_SystemHealthEvent primary key(CollectSystemTime, EventName, EventHash) with (data_compression = page) on PS_SchemaZPartitionGeneric(CollectSystemTime)
	) on PS_SchemaZPartitionGeneric(CollectSystemTime)
end


