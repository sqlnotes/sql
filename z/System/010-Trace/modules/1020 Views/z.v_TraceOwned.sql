/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/010-Trace/modules/1020%20Views/z.v_TraceOwned.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/010-Trace/docs/reference/supporting-objects.md#zv_traceowned

Lists registered native traces created by the current session.
*/
create or alter view z.v_TraceOwned
as
	select t.TraceID, t.Name, t.Description, t.CreationDate, t.ModificationDate, t.CreatorSessionID, t.CreatorLoginTime,
		t.ReceivingTable, t.Status
	from z.v_Trace t
	where t.CreatorSessionID = @@spid
		and t.CreatorLoginTime = (select login_time from sys.dm_exec_sessions where session_id = @@spid);
go
