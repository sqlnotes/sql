/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/010-Trace/baseline/2020%20Tables/z.TraceEvent.sql
*/
if object_id(N'z.TraceEvent') is null
begin
	create table z.TraceEvent
	(
		TraceID int not null,
		EventID int not null,
		constraint PK_z_TraceEvent primary key (TraceID, EventID)
	)
end
