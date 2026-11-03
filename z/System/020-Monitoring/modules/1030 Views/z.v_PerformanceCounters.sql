/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/020-Monitoring/modules/1030%20Views/z.v_PerformanceCounters.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/020-Monitoring/docs/reference/supporting-objects.md#zv_performancecounters

Reports live raw performance counters with counter-type names and descriptions.
*/
create or alter view z.v_PerformanceCounters
as
	select p.object_name ObjectName, p.counter_name CounterName, p.instance_name InstanceName,
		p.cntr_value CounterValue, p.cntr_type CounterType, t.CounterTypeName, t.Description CounterTypeDescription
	from sys.dm_os_performance_counters p
		left join z.v_PerformanceCounterTypes t on t.CounterType = p.cntr_type
