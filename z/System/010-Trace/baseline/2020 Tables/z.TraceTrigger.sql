/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/010-Trace/baseline/2020%20Tables/z.TraceTrigger.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/010-Trace/docs/reference/supporting-objects.md#ztracetrigger

Stores stored-procedure callback registrations for native trace events.
*/
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
