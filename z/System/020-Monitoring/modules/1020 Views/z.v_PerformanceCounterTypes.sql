/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/020-Monitoring/modules/1020%20Views/z.v_PerformanceCounterTypes.sql
*/
create or alter view z.v_PerformanceCounterTypes
as
	select t.CounterType, cast(t.CounterTypeName as nvarchar(64)) CounterTypeName, cast(t.Description as nvarchar(512)) Description
	from (values
		(65792, N'PERF_COUNTER_LARGE_RAWCOUNT', N'Last observed 64-bit raw value. Read directly in the units defined by the counter.'),
		(272696320, N'PERF_COUNTER_COUNTER', N'Cumulative 32-bit event count. Calculate the per-second rate from the value change divided by elapsed seconds between two samples.'),
		(272696576, N'PERF_COUNTER_BULK_COUNT', N'Cumulative 64-bit event count. Calculate the per-second rate from the value change divided by elapsed seconds between two samples.'),
		(537003264, N'PERF_LARGE_RAW_FRACTION', N'64-bit ratio numerator. Calculate the current percentage as 100 times this value divided by its matching base counter.'),
		(1073874176, N'PERF_AVERAGE_BULK', N'Average amount per operation. Divide the change in this accumulated value by the change in its matching base counter between two samples.'),
		(1073939712, N'PERF_LARGE_RAW_BASE', N'64-bit denominator for an associated SQL Server ratio or average counter. Use with the matching numerator counter.')
	) t(CounterType, CounterTypeName, Description)
