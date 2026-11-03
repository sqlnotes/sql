/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/010-Trace/baseline/2020%20Tables/z.TraceEventColumn.sql
*/
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
