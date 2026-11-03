/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/020-Monitoring/baseline/2020%20Tables/z.ErrorEvent.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/020-Monitoring/docs/reference/extended-events.md#zerrorevent

Stores decoded error events with UTC timestamps and original Extended Events XML.
*/
if object_id(N'z.ErrorEvent') is null
begin
	create table z.ErrorEvent
	(
		EventDateUTC datetime not null,
		EventName nvarchar(128) not null,
		EventSequence bigint not null,
		ErrorNumber int,
		Severity int,
		State int,
		IsUserDefined bit,
		ErrorCategory int,
		ErrorCategoryText nvarchar(100),
		ErrorDestination int,
		ErrorDestinationText nvarchar(100),
		IsIntercepted bit,
		ErrorMessage nvarchar(max),
		SQLText nvarchar(max),
		SessionServerPrincipalName nvarchar(128),
		ServerInstanceName nvarchar(128),
		DatabaseName nvarchar(128),
		ContextInfo varchar(512),
		HostName nvarchar(128),
		ApplicationName nvarchar(128),
		EventBody xml not null,
		constraint PK_z_ErrorEvent primary key(EventDateUTC, EventName, EventSequence) with (data_compression = page) on PS_SchemaZPartitionGenericDateTime(EventDateUTC)
	) on PS_SchemaZPartitionGenericDateTime(EventDateUTC)
end
