create or alter trigger z.TRI_v_DatabaseBackupStatus on z.v_DatabaseBackupStatus
instead of update
as
begin
	set nocount, xact_abort on;
	if update(BackupType) or update(DatabaseID) or update(DatabaseName) or update(CreateDate) or update(IsReadOnly)
		or update(StateDescription) or update(BackupStatus) or update(MetadataStatus)
		throw 50000, 'Only RunID, SettingsHash, SessionID, StartDate and EndDate can be updated.', 1;
	if not exists(select * from inserted) return;
	if exists(select * from inserted where
		(RunID is null and (SettingsHash is not null or SessionID is not null or StartDate is not null or EndDate is not null))
		or (RunID is not null and (datalength(RunID) <> 64 or RunID collate Latin1_General_100_BIN2 like '%[^0-9A-F]%'))
		or (RunID is not null and (SettingsHash is null or datalength(SettingsHash) <> 64 or SettingsHash collate Latin1_General_100_BIN2 like '%[^0-9A-F]%'))
		or SessionID <= 0 or (StartDate is null and (SessionID is not null or EndDate is not null))
		or (StartDate is not null and SessionID is null) or EndDate < StartDate)
		throw 50000, 'Invalid database backup status values.', 1;
	-- Match the existing coordinator gate, retaining ownership until the caller commits.
	if applock_mode('public', N'z.Backup.Register', 'Session') <> 'NoLock'
		throw 50000, 'Release the session backup registration lock before updating the status view.', 1;
	declare @Result int, @BackupType varchar(4), @DatabaseID int, @DatabaseName sysname, @CreateDate datetime,
		@RunID varchar(64), @SettingsHash varchar(64), @SessionID int, @StartDate datetime2(7), @EndDate datetime2(7),
		@Property sysname, @Json nvarchar(max), @Value nvarchar(4000);
	exec @Result = sys.sp_getapplock @Resource = N'z.Backup.Register', @LockMode = 'Exclusive', @LockOwner = 'Transaction', @LockTimeout = 60000, @DbPrincipal = 'public';
	if @Result < 0 throw 50000, 'Could not acquire the backup status update lock.', 1;
	-- The UPDATE snapshot may predate the gate. Reject changed rows instead of losing another writer's update.
	if exists(
		select DatabaseID, BackupType, DatabaseName collate Latin1_General_100_BIN2, CreateDate,
			RunID collate Latin1_General_100_BIN2, SettingsHash collate Latin1_General_100_BIN2, SessionID, StartDate, EndDate, MetadataStatus from deleted
		except
		select v.DatabaseID, v.BackupType, v.DatabaseName collate Latin1_General_100_BIN2, v.CreateDate,
			v.RunID collate Latin1_General_100_BIN2, v.SettingsHash collate Latin1_General_100_BIN2, v.SessionID, v.StartDate, v.EndDate, v.MetadataStatus
		from z.v_DatabaseBackupStatus v inner join deleted d on d.DatabaseID = v.DatabaseID and d.BackupType = v.BackupType)
		throw 50000, 'Database backup status changed during the update; read it again and retry.', 1;
	declare c cursor local fast_forward for
		select DatabaseID, BackupType, DatabaseName, CreateDate, RunID, SettingsHash, SessionID, StartDate, EndDate from inserted order by DatabaseID, BackupType;
	open c;
	fetch next from c into @DatabaseID, @BackupType, @DatabaseName, @CreateDate, @RunID, @SettingsHash, @SessionID, @StartDate, @EndDate;
	while @@fetch_status = 0
	begin
		select @Property = N'z.Backup.Work.' + convert(nvarchar(20), @DatabaseID) + N'.' + @BackupType;
		if @RunID is null
		begin
			if exists(select * from sys.extended_properties where class = 0 and major_id = 0 and minor_id = 0 and name = @Property)
			begin
				exec @Result = sys.sp_dropextendedproperty @name = @Property;
				if isnull(@Result, 1) <> 0 throw 50000, 'Could not clear the database backup status property.', 1;
			end
		end
		else
		begin
			select @Json = (select @DatabaseID DatabaseID, @DatabaseName DatabaseName, @CreateDate CreateDate, @BackupType BackupType,
				@RunID RunID, @SettingsHash SettingsHash, @SessionID SessionID, @StartDate StartDate, @EndDate EndDate for json path, include_null_values, without_array_wrapper);
			if datalength(@Json) > 7500 throw 50000, 'Database backup status property exceeds 7500 bytes.', 1;
			select @Value = @Json;
			if exists(select * from sys.extended_properties where class = 0 and major_id = 0 and minor_id = 0 and name = @Property)
				exec @Result = sys.sp_updateextendedproperty @name = @Property, @value = @Value;
			else exec @Result = sys.sp_addextendedproperty @name = @Property, @value = @Value;
			if isnull(@Result, 1) <> 0 throw 50000, 'Could not write the database backup status property.', 1;
		end
		fetch next from c into @DatabaseID, @BackupType, @DatabaseName, @CreateDate, @RunID, @SettingsHash, @SessionID, @StartDate, @EndDate;
	end
	close c;
	deallocate c;
end
go
