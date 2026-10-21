if object_id(N'z.TraceEvent') is null
begin
	create table z.TraceEvent
	(
		TraceID int not null,
		EventID int not null,
		constraint PK_z_TraceEvent primary key (TraceID, EventID)
	)
end
