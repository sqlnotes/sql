create or alter procedure z.usp_CheckSystemHealthTrace
as
begin
	set nocount on
    ;with x0 as
	(
		select 
				datediff_big(second, '1900-01-01', Date) * 268435456 | cast(datediff(millisecond, convert(datetime, convert(char(19), Date, 120)), Date) as bigint) CollectSystemTime,
				EventName, cast(hashbytes('MD5', cast(EventBody as varbinary(max))) as uniqueidentifier) EventHash , EventBody
		from z.fn_ExtractSystemHealthEvent()
		where EventName not in (
								'security_error_ring_buffer_recorded', 'connectivity_ring_buffer_recorded', 
								'scheduler_monitor_system_health_ring_buffer_recorded', 'sp_server_diagnostics_component_result', 
								'memory_broker_ring_buffer_recorded'
							)
	)

      insert into z.SystemHealthEvent(CollectSystemTime, EventName, EventHash, EventBody)
            select CollectSystemTime, EventName, EventHash, EventBody
            from x0
            where not exists(select * from z.SystemHealthEvent e where e.CollectSystemTime = x0.CollectSystemTime and e.EventName = x0.EventName and e.EventHash =x0.EventHash)    
end

