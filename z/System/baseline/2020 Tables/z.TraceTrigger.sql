--drop table z.TraceTrigger
if object_id('z.TraceTrigger') is null
begin
	create table z.TraceTrigger
	(
		TraceID int,
		EventName varchar(128) not null,
		ProcedureName nvarchar(128) not null
		constraint PK_z_TraceTrigger primary key (TraceID, EventName),
		constraint FK_z_TraceTrigger_Trace_TraceID foreign key (TraceID) references z.Trace(TraceID) on delete cascade
	)
end

