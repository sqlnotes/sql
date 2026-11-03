/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/020-Monitoring/baseline/2020%20Tables/z.PerformanceCounters.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/020-Monitoring/docs/reference/z.usp_CollectPerformanceCounters.md

Stores sampled and calculated SQL Server performance-counter measurements.
*/
if object_id(N'z.PerformanceCounters') is null
begin
	create table z.PerformanceCounters
	(
		Date datetime not null,
		ObjectName nvarchar(128) not null,
		CounterName nvarchar(128) not null,
		InstanceName nvarchar(128) not null,
		CounterType int not null,
		CounterValue float,
		RawValue bigint not null,
		BaseValue bigint,
		ElapsedSeconds float not null,
		constraint PK_z_PerformanceCounters primary key(Date, ObjectName, CounterName, InstanceName) with (data_compression = page) on PS_SchemaZPartitionGenericDateTime(Date)
	) on PS_SchemaZPartitionGenericDateTime(Date)
end
