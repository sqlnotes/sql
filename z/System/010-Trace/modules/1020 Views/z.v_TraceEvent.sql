/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/010-Trace/modules/1020%20Views/z.v_TraceEvent.sql
*/
create or alter view z.v_TraceEvent
as
	select te.trace_event_id TraceEventID, tc.name CategoryName, te.Name EventName 
	from sys.trace_categories tc
		inner join sys.trace_events te on te.category_id = tc.category_id