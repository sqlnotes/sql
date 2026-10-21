if object_id(N'z.TraceEventColumn') is null
begin
	create table z.TraceEventColumn
	(
		TraceID int not null,
		EventID int not null,
		ColumnID int not null,
		constraint PK_z_TraceEventColumn primary key (TraceID, EventID, ColumnID)
	)
end
