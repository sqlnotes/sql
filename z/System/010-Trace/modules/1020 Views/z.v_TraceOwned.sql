create or alter view z.v_TraceOwned
as
	select t.TraceID, t.Name, t.Description, t.CreationDate, t.ModificationDate, t.CreatorSessionID, t.ReceivingTable,
		t.CollectorUUID, t.IsEnabled, t.State, t.NativeTraceID, t.NativeStartTime, t.NativeStopTime, t.Status
	from z.v_Trace t
		inner join z.TraceCollector c on c.CollectorUUID = t.CollectorUUID
	where c.OwnerSessionID = @@spid
		and c.OwnerLoginTime = (select login_time from sys.dm_exec_sessions where session_id = @@spid)
		and c.CollectorUUID = try_convert(uniqueidentifier, session_context(N'Schema z.TraceCollector.UUID'));
go
