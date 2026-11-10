/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/010-Trace/modules/1020%20Views/z.v_Trace.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/010-Trace/docs/reference/supporting-objects.md#zv_trace

Lists registered native traces and their current SQL Server state.
*/
create or alter view z.v_Trace
as
	select t.TraceID, t.Name, t.Description, t.CreationDate, t.ModificationDate, t.CreatorSessionID, t.CreatorLoginTime,
		t.ReceivingTable,
		convert(varchar(16), case when n.status = 1 then 'Running' when n.status = 0 then 'Stopped' else 'Not Available' end) Status
	from z.Trace t
		left join sys.traces n on n.id = t.TraceID and n.is_rowset = 1 and n.stop_time is null;
go
