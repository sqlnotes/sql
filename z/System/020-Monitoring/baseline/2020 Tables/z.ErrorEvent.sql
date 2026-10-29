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
