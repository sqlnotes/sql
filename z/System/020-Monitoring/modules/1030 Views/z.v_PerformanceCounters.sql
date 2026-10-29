create or alter view z.v_PerformanceCounters
as
	select p.object_name ObjectName, p.counter_name CounterName, p.instance_name InstanceName,
		p.cntr_value CounterValue, p.cntr_type CounterType, t.CounterTypeName, t.Description CounterTypeDescription
	from sys.dm_os_performance_counters p
		left join z.v_PerformanceCounterTypes t on t.CounterType = p.cntr_type
