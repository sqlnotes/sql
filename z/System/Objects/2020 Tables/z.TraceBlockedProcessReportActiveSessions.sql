if object_id('z.TraceBlockedProcessReportActiveSessions') is null
begin
	create table z.TraceBlockedProcessReportActiveSessions
	(
		TraceSequence bigint not null,
		SnapshotDate datetime not null constraint DF_z_TraceBlockedProcessReportActiveSessions_SnapshotDate  default(getdate()),
		SessionID smallint not null,
		ActiveSessionID bigint not null constraint DF_z_TraceBlockedProcessReportActiveSessions_ActiveSessionID  default(datediff_big(second,'1900-01-01',getutcdate())*(268435456)|next value for z.SeqGeneralID),
		StartDate datetime not null,
		BlockingSessionID smallint,
		DurationInSecond int,
		Status nvarchar(30) not null,
		Command nvarchar(32) not null,
		WaitType nvarchar(60),
		WaitTime int not null,
		WaitResource nvarchar(256) not null,
		LastWaitType nvarchar(60) not null,
		CPU int not null,
		Reads bigint not null,
		Writes bigint not null,
		LogicalReads bigint not null,
		TotalElapsedTime int not null,
		DatabaseName nvarchar(128),
		SQLText nvarchar(max),
		QueryPlan xml,
		GrantedMemory int not null,
		NestedLevel int not null,
		[RowCount] bigint not null,
		OpenTranCount int not null,
		TransactionIsolationLevel smallint not null,
		LoginName nvarchar(128),
		HostName nvarchar(128),
		HostAddress nvarchar(48),
		ApplicationName nvarchar(128),
		constraint PK_z_TraceBlockedProcessReportActiveSessions primary key(TraceSequence, SnapshotDate, SessionID, ActiveSessionID) with (data_compression = page) on PS_SchemaZPartitionGeneric(TraceSequence)
	) on PS_SchemaZPartitionGeneric(TraceSequence)
end