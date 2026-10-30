if object_id(N'z.PerformanceCounters') is null
begin
	create table z.PerformanceCounters
	(
		Date datetime not null,
		ObjectName nvarchar(128) not null,
		CounterName nvarchar(128) not null,
		InstanceName nvarchar(128) not null,
		CounterType int not null,
		CounterValue float,
		RawValue bigint not null,
		BaseValue bigint,
		ElapsedSeconds float not null,
		constraint PK_z_PerformanceCounters primary key(Date, ObjectName, CounterName, InstanceName) with (data_compression = page) on PS_SchemaZPartitionGenericDateTime(Date)
	) on PS_SchemaZPartitionGenericDateTime(Date)
end
