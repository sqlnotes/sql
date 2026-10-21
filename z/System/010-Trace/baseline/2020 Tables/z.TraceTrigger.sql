if object_id(N'z.TraceTrigger') is null
begin
	create table z.TraceTrigger
	(
		TraceID int not null,
		EventName nvarchar(128) not null,
		ProcedureName nvarchar(517) not null,
		constraint PK_z_TraceTrigger primary key (TraceID, EventName)
	)
end
