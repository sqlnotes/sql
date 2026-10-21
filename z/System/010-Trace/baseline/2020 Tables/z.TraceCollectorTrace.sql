if object_id(N'z.TraceCollectorTrace', N'U') is null
begin
	create table z.TraceCollectorTrace
	(
		CollectorUUID uniqueidentifier not null,
		TraceID int not null,
		NativeStartTime datetime,
		NativeStopTime datetime not null,
		TraceName nvarchar(128) not null,
		constraint PK_z_TraceCollectorTrace primary key (CollectorUUID),
		index IX_z_TraceCollectorTrace_TraceID (TraceID, NativeStopTime)
	);
end;
