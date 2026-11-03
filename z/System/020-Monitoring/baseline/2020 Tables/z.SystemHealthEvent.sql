/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/020-Monitoring/baseline/2020%20Tables/z.SystemHealthEvent.sql
*/
if object_id('z.SystemHealthEvent') is null
begin
	create table z.SystemHealthEvent
	(
		EventDateUTC datetime not null,
		EventName nvarchar(128) not null,
		EventHash uniqueidentifier not null,
		EventBody xml not null,
		constraint PK_z_SystemHealthEvent primary key(EventDateUTC, EventName, EventHash) with (data_compression = page) on PS_SchemaZPartitionGenericDateTime(EventDateUTC)
	) on PS_SchemaZPartitionGenericDateTime(EventDateUTC)
end
