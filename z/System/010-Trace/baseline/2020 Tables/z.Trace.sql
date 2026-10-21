if object_id(N'z.Trace') is null
begin
	create table z.Trace
	(
		TraceID int identity not null,
		CollectorUUID uniqueidentifier not null,
		Name nvarchar(128) not null,
		Description nvarchar(max),
		CreationDate datetime not null constraint DF_z_Trace_CreationDate default(getdate()),
		ModificationDate datetime not null constraint DF_z_Trace_ModificationDate default(getdate()),
		ReceivingTable nvarchar(128) not null,
		CreatorSessionID int not null constraint DF_z_Trace_CreatorSessionID default(@@spid),
		IsEnabled bit not null constraint DF_z_Trace_IsEnabled default(0),
		constraint PK_z_Trace primary key (TraceID),
		constraint UQ_z_Trace_CollectorUUID_Name unique (CollectorUUID, Name),
		index IDX_z_Trace_CreatorSessionID (CreatorSessionID)
	)
end
