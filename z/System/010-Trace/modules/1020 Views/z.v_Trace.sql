create or alter view z.v_Trace
as
	select t.TraceID, t.Name, t.Description, t.CreationDate, t.ModificationDate, t.CreatorSessionID, t.ReceivingTable,
		t.CollectorUUID, t.IsEnabled, c.State, m.TraceID NativeTraceID, m.NativeStartTime, m.NativeStopTime,
		convert(varchar(16), case when t.IsEnabled = 0 then 'Stopped' when c.State = 'Building' then 'Running'
			when n.status = 1 then 'Running' when n.status = 0 then 'Stopped' else 'Not Available' end) Status
	from z.Trace t
		inner join z.TraceCollector c on c.CollectorUUID = t.CollectorUUID
		left join z.TraceCollectorTrace m on m.CollectorUUID = t.CollectorUUID
		left join sys.traces n on n.id = m.TraceID and n.stop_time = m.NativeStopTime
			and (m.NativeStartTime is null or n.start_time = m.NativeStartTime);
go
