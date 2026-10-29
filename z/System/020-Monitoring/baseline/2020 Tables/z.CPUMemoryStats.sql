if object_id(N'z.CPUMemoryStats') is null
begin
	create table z.CPUMemoryStats
	(
		Date datetime not null,
		SystemIdle int,
		SQLProcessUtilization int,
		Other int,
		UserModeTime bigint,
		KernelModeTime bigint,
		PageFaults int,
		WorkingSetDelta bigint,
		MemoryUtilizationPercentage int,
		constraint PK_z_CPUMemoryStats primary key(Date) with (data_compression = page) on PS_SchemaZPartitionGenericDateTime(Date)
	) on PS_SchemaZPartitionGenericDateTime(Date)
end
else if exists(select 1 from sys.columns where object_id = object_id(N'z.CPUMemoryStats') and name = N'WorkingSetDelta' and system_type_id = type_id(N'int'))
	alter table z.CPUMemoryStats alter column WorkingSetDelta bigint null;
