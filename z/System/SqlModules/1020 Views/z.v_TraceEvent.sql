create or alter view z.v_TraceEvent
as
	select te.trace_event_id TraceEventID, tc.name CategoryName, te.Name EventName 
	from sys.trace_categories tc
		inner join sys.trace_events te on te.category_id = tc.category_id