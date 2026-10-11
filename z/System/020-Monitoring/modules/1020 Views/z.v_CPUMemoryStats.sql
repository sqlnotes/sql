create or alter view z.v_CPUMemoryStats
as
with x1 as
( 
		select dateadd(ms, -1 * (i.ms_ticks - b.timestamp), getdate()) Date, cast(b.record as xml) AS Data
		from sys.dm_os_ring_buffers b
			cross join sys.dm_os_sys_info i
		where ring_buffer_type = N'RING_BUFFER_SCHEDULER_MONITOR' 
			and record like '%<SystemHealth>%'

),
x2 as
(
	select	Date, 
			c.value('../../@id', 'int') RecordID, 
			c.value('(SystemIdle)[1]', 'int') SystemIdle,
			c.value('(ProcessUtilization)[1]', 'int') SQLProcessUtilization,
			c.value('(UserModeTime)[1]', 'bigint') as UserModeTime_100ns,
			c.value('(KernelModeTime)[1]', 'bigint') AS KernelModeTime_100ns,
			c.value('PageFaults[1]', 'int') AS PageFaults,
			c.value('(WorkingSetDelta)[1]', 'int') AS WorkingSetDelta,
			c.value('MemoryUtilization[1]', 'int') AS MemoryUtilizationPercentage

	from x1
		cross apply Data.nodes('/Record/SchedulerMonitorEvent/SystemHealth') n(c)
)
select x2.RecordID, x2.Date, x2.SystemIdle, x2.SQLProcessUtilization, 100 - x2.SystemIdle - x2.SQLProcessUtilization Other,
		x2.UserModeTime_100ns UserModeTime, x2.KernelModeTime_100ns KernelModeTime, 
		x2.PageFaults, x2.WorkingSetDelta, x2.MemoryUtilizationPercentage
from x2


 