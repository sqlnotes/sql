create or alter procedure z.usp_CollectSystemHealthEvents
as
begin
	set nocount on;
	declare @TargetData xml;

	select @TargetData = cast(t.target_data as xml)
	from sys.dm_xe_sessions s
		inner join sys.dm_xe_session_targets t on t.event_session_address = s.address
	where s.name = N'system_health' and t.target_name = N'ring_buffer';
	if @TargetData is null return;

	;with x as
	(
		select EventDateUTC, EventName, EventHash, EventBody
		from z.fn_ExtractSystemHealthEvent(@TargetData)
		where EventName not in (
			'security_error_ring_buffer_recorded', 'connectivity_ring_buffer_recorded',
			'scheduler_monitor_system_health_ring_buffer_recorded', 'sp_server_diagnostics_component_result',
			'memory_broker_ring_buffer_recorded'
		)
	)
	insert into z.SystemHealthEvent(EventDateUTC, EventName, EventHash, EventBody)
		select EventDateUTC, EventName, EventHash, EventBody
		from x
		where not exists (
			select 1 from z.SystemHealthEvent e
			where e.EventDateUTC = x.EventDateUTC and e.EventName = x.EventName and e.EventHash = x.EventHash
		);
end
