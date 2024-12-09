if object_id('z.Trace') is null
begin
	create table z.Trace
	(
		TraceID int,
		Name nvarchar(128) not null,
		Description nvarchar(max),
		CreationDate datetime not null constraint DF_z_Trace_CreationDate default(getdate()),
		ModificationDate datetime not null constraint DF_z_Trace_ModificationDate default(getdate()),
		ReceivingTable nvarchar(128) not null,
		CreatorSessionID int not null constraint DF_z_Trace_CreatorSessionID default(@@spid),
		constraint PK_z_Trace primary key (TraceID),
		index IDX_z_Trace_Name unique(Name),
		index IDX_z_Trace_CreatorSessionID (CreatorSessionID)
	)
end

