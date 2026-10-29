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
