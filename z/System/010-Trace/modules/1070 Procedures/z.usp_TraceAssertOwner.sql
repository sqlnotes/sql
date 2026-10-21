create or alter procedure z.usp_TraceAssertOwner
(
	@TraceName nvarchar(128) = null,
	@TraceID int = null
)
as
begin
	set nocount on;
	if not exists
	(
		select 1 from z.TraceCollector c
		where c.CollectorUUID = try_convert(uniqueidentifier, session_context(N'Schema z.TraceCollector.UUID'))
			and c.OwnerSessionID = @@spid
			and c.OwnerLoginTime = (select login_time from sys.dm_exec_sessions where session_id = @@spid)
	)
		throw 50000, N'The current session does not own a registered trace collector.', 1;
	-- Names are run-local; an identically named definition in another run is allowed.
	if @TraceID is not null and exists
	(
		select 1 from z.Trace t where t.TraceID = @TraceID
			and t.CollectorUUID <> try_convert(uniqueidentifier, session_context(N'Schema z.TraceCollector.UUID'))
	)
		throw 50000, N'The selected logical trace is not owned by the current collector session.', 1;
end;
go
