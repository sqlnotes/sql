/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/010-Trace/baseline/2020%20Tables/z.Trace.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/010-Trace/docs/reference/supporting-objects.md#ztrace

Registers native rowset traces, destinations, and their creating sessions.
*/
-- Existing logical collectors must be closed with the previous installation first.
if col_length(N'z.Trace', N'CollectorUUID') is not null or columnproperty(object_id(N'z.Trace'), N'TraceID', 'IsIdentity') = 1
begin
	if exists(select 1 from z.Trace)
		throw 50000, N'Close all existing traces with the previous installation before switching to native trace registration.', 1;
	if object_id(N'z.TraceCollectorTrace', N'U') is not null
		exec sys.sp_executesql N'if exists(select 1 from z.TraceCollectorTrace) throw 50000, N''Close existing native generations before switching trace registration.'', 1;';
	if object_id(N'z.TraceCollector', N'U') is not null
		exec sys.sp_executesql N'if exists(select 1 from z.TraceCollector) throw 50000, N''Release existing collector sessions before switching trace registration.'', 1;';
	if exists(select 1 from z.TraceEvent) or exists(select 1 from z.TraceEventColumn)
		or exists(select 1 from z.TraceFilter) or exists(select 1 from z.TraceTrigger)
		throw 50000, N'Remove retained trace configuration with the previous installation before switching trace registration.', 1;
	drop table z.Trace;
end;
if object_id(N'z.Trace', N'U') is null
begin
	create table z.Trace
	(
		TraceID int not null,
		Name nvarchar(128) not null,
		Description nvarchar(max),
		CreationDate datetime not null constraint DF_z_Trace_CreationDate default(getdate()),
		ModificationDate datetime not null constraint DF_z_Trace_ModificationDate default(getdate()),
		ReceivingTable nvarchar(128) not null,
		CreatorSessionID int not null,
		CreatorLoginTime datetime not null,
		constraint PK_z_Trace primary key (TraceID),
		constraint UQ_z_Trace_Owner_Name unique (CreatorSessionID, CreatorLoginTime, Name)
	);
end;
