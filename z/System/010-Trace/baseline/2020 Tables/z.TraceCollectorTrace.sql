if object_id(N'z.TraceCollectorTrace', N'U') is null
begin
	create table z.TraceCollectorTrace
	(
		CollectorUUID uniqueidentifier not null,
		TraceID int not null,
		NativeStartTime datetime,
		NativeStopTime datetime not null,
		TraceName nvarchar(128) not null,
		constraint PK_z_TraceCollectorTrace primary key (CollectorUUID, TraceID, NativeStopTime),
		index IX_z_TraceCollectorTrace_TraceID (TraceID, NativeStopTime)
	);
end;

-- Eligible baseline replay upgrades only the original single-generation key.
if exists
(
	select 1 from sys.key_constraints k
	where k.parent_object_id = object_id(N'z.TraceCollectorTrace') and k.name = N'PK_z_TraceCollectorTrace' and k.type = 'PK'
		and exists(select 1 from sys.index_columns i inner join sys.columns c on c.object_id = i.object_id and c.column_id = i.column_id
			where i.object_id = k.parent_object_id and i.index_id = k.unique_index_id and i.key_ordinal = 1 and c.name = N'CollectorUUID')
		and not exists(select 1 from sys.index_columns i where i.object_id = k.parent_object_id and i.index_id = k.unique_index_id and i.key_ordinal > 1)
)
begin
	begin try
		begin tran;
		alter table z.TraceCollectorTrace drop constraint PK_z_TraceCollectorTrace;
		alter table z.TraceCollectorTrace add constraint PK_z_TraceCollectorTrace primary key (CollectorUUID, TraceID, NativeStopTime);
		commit;
	end try
	begin catch
		if @@trancount > 0 rollback;
		throw;
	end catch;
end;
