/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/020-Monitoring/baseline/2020%20Tables/z.LongRunningQueryEvent.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/020-Monitoring/docs/reference/extended-events.md#zlongrunningqueryevent

Stores decoded completion events with UTC timestamps and original Extended Events XML.
*/
if object_id(N'z.LongRunningQueryEvent') is null
begin
	create table z.LongRunningQueryEvent
	(
		EventDateUTC datetime not null,
		EventName nvarchar(128) not null,
		EventSequence bigint not null,
		SessionID int,
		CPU bigint,
		DurationInMS numeric(38,3),
		PhysicalReads bigint,
		LogicalReads bigint,
		Writes bigint,
		[RowCount] bigint,
		ConnectionResetOption nvarchar(50),
		ObjectName nvarchar(128),
		SQLText nvarchar(max),
		ServerPrincipalName nvarchar(128),
		DatabaseName nvarchar(128),
		ContextInfo varchar(512),
		HostName nvarchar(128),
		ApplicationName nvarchar(128),
		EventBody xml not null,
		constraint PK_z_LongRunningQueryEvent primary key(EventDateUTC, EventName, EventSequence) with (data_compression = page) on PS_SchemaZPartitionGenericDateTime(EventDateUTC)
	) on PS_SchemaZPartitionGenericDateTime(EventDateUTC)
end
