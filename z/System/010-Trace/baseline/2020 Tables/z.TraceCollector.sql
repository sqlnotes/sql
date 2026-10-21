if object_id(N'z.TraceCollector', N'U') is null
begin
	create table z.TraceCollector
	(
		CollectorUUID uniqueidentifier not null,
		OwnerSessionID smallint not null,
		OwnerLoginTime datetime not null,
		State varchar(10) not null constraint DF_z_TraceCollector_State default ('Building'),
		CreationDate datetime2 not null constraint DF_z_TraceCollector_CreationDate default (sysdatetime()),
		constraint PK_z_TraceCollector primary key (CollectorUUID),
		constraint UQ_z_TraceCollector_Owner unique (OwnerSessionID, OwnerLoginTime),
		constraint CK_z_TraceCollector_State check (State in ('Building', 'Collecting'))
	);
end;
