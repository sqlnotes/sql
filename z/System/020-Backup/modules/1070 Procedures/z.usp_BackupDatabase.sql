create or alter procedure z.usp_BackupDatabase
(
	@Databases nvarchar(max) = 'AllDatabases', --'AllDatabases', 'UserDatabases', 'SystemDatabases', 'Database1,Dabase2...'
	@BackupType nvarchar(50) = 'Full', --'Full, Log, Diff'
	@BackupFolder nvarchar(4000) = null, --Folder used to save the backup.
	@BackupCompression bit = 1,
	@OtherBackupOptions nvarchar(max) = null,-- 'stats = 1',
	@RetentionHours int = 30,
	@UseBackupHeader bit = 0
)
as
begin
	set nocount on;
	set xact_abort off;
	if @@trancount <> 0 throw 50000, 'Backup cannot run inside a transaction.', 1;
	set xact_abort on;
	if @UseBackupHeader is null throw 50000, '@UseBackupHeader must be 0 or 1.', 1;
	if @RetentionHours <= 0 throw 50000, '@RetentionHours must be positive or NULL (disabled).', 1;
	declare @BackupPath nvarchar(4000), @SQL nvarchar(max), @DatabaseName nvarchar(128), @StandardizedDatabaseName nvarchar(128), @FolderSeparator varchar(1), @BackupFileName nvarchar(4000), @DatabaseBackupFolder nvarchar(4000), @RawPath nvarchar(max), @Platform nvarchar(256), @LockName nvarchar(255), @LockResult int, @LockHeld bit = 0, @DirectoryResult int, @Character int = 1
	declare @RunID varchar(64), @SettingsHash varchar(64), @Canonical nvarchar(max),
		@GroupLock nvarchar(255), @GroupHeld bit = 0, @DatabaseLock nvarchar(255), @DatabaseLockHeld bit = 0,
		@DatabaseID int, @DatabaseCreateDate datetime, @StartDate datetime2(7), @HasWork bit, @Pending bit = 1,
		@OtherWorkers bit, @NewBatch bit;
	select @BackupType = upper(trim(@BackupType));
	if nullif(trim(translate(@OtherBackupOptions, nchar(9) + nchar(10) + nchar(11) + nchar(12) + nchar(13), N'     ')), N'') is null
		select @OtherBackupOptions = null;
	if @BackupType is null or @BackupType not in ('FULL', 'LOG', 'DIFF')
	begin
		throw 50000, '@BackupType must be Full, Log, or Diff', 1;
	end
	if @BackupCompression is null
		select @BackupCompression = isnull((select cast(value as int) from sys.configurations where name = 'backup compression default'), 0)
	declare @DatabaseList table(
								DatabaseName nvarchar(128) primary key,
								DatabaseID int not null, CreateDate datetime not null,
								StandardizedDatabaseName nvarchar(128) not null,
								DataSizeMB bigint
							)
	insert into @DatabaseList(DatabaseName, DatabaseID, CreateDate, StandardizedDatabaseName, DataSizeMB)
		select	d.name, d.database_id, d.create_date,
				replace(translate(d.name, '<>:"/\?*', '        '), ' ', '_'),
				sum(cast(m.size as bigint)) *8/1024
		from sys.databases d
			inner join sys.master_files m on m.database_id = d.database_id
		where d.state_desc not in ('RESTORING', 'RECOVERING', 'RECOVERY_PENDING', 'SUSPECT', 'EMERGENCY')
			and d.name not in ('tempdb')
			and m.type_desc in ('ROWS')
			and (
						@Databases = 'AllDatabases'
					or	@Databases = 'UserDatabases' and d.name not in ('master', 'tempdb', 'model', 'msdb')
					or	@Databases = 'SystemDatabases' and d.name in ('master', 'tempdb', 'model', 'msdb')
					or  exists(select * from string_split(@Databases, ',') ss where ltrim(rtrim(ss.value)) = d.name)
				)
			and (
					@BackupType in ('FULL', 'DIFF')
					or d.recovery_model_desc <> 'SIMPLE'
				)
		group by d.name, d.database_id, d.create_date
	if not exists(select * from @DatabaseList)
	begin
		print 'No databases to be backup.'
		return
	end
	if @BackupFolder is null
	begin
		select @BackupFolder = cast(serverproperty('InstanceDefaultBackupPath') as nvarchar(4000))
	end
	if @BackupFolder is null
	begin
		throw 50000, 'Please specify backup folder', 1;
	end

	select @Platform = host_platform from sys.dm_os_host_info;
	if @Platform is null or @Platform not in (N'Windows', N'Linux') throw 50000, 'Unsupported backup filesystem platform.', 1;
	select @FolderSeparator = iif(@Platform = N'Linux', '/', '\');
	if len(@BackupFolder) = 0 or datalength(@BackupFolder) <> datalength(rtrim(@BackupFolder)) or len(@BackupFolder) > 3500
		throw 50000, 'Backup folder is empty, too long or contains trailing spaces.', 1;
	if @BackupFolder like N'%[*?]%' or exists(select * from string_split(replace(@BackupFolder, N'\', N'/'), N'/') where value in (N'.', N'..'))
		throw 50000, 'Backup folder cannot contain wildcard or dot path segments.', 1;
	while @Character <= datalength(@BackupFolder) / 2
	begin
		if unicode(substring(@BackupFolder, @Character, 1)) < 32 throw 50000, 'Backup folder cannot contain control characters.', 1;
		select @Character += 1;
	end
	if (@Platform = N'Linux' and charindex(N'//', @BackupFolder) > 0)
		or (@Platform = N'Windows' and (charindex(N'\\', substring(@BackupFolder, 3, len(@BackupFolder))) > 0
			or charindex(N':', substring(@BackupFolder, 3, len(@BackupFolder))) > 0
			or exists(select * from string_split(@BackupFolder, N'\') where right(value, 1) in (N'.', N' '))))
		throw 50000, 'Backup folder contains ambiguous separators or Windows path aliases.', 1;
	if @Platform = N'Linux' and (left(@BackupFolder, 1) <> N'/' or charindex(N'\', @BackupFolder) > 0)
		throw 50000, 'Linux backup folders must be absolute mounted filesystem paths.', 1;
	if @Platform = N'Windows' and (charindex(N'/', @BackupFolder) > 0 or not
		(left(@BackupFolder, 3) like N'[A-Za-z]:\' or (left(@BackupFolder, 2) = N'\\' and charindex(N'\', @BackupFolder, 3) > 3
		and len(@BackupFolder) > charindex(N'\', @BackupFolder, 3))))
		throw 50000, 'Windows backup folders must be absolute drive or UNC paths.', 1;
	while right(@BackupFolder, 1) in ('/', '\') and len(@BackupFolder) > 1
		select @BackupFolder = left(@BackupFolder, len(@BackupFolder) -1)

	if right(@BackupFolder, 1) <> @FolderSeparator
		select @BackupFolder = @BackupFolder + @FolderSeparator

	select @Canonical = (select DatabaseName from @DatabaseList order by DatabaseName collate Latin1_General_100_BIN2 for json path);
	select @RunID = convert(varchar(64), hashbytes('SHA2_256', convert(varbinary(max), @Canonical)), 2);
	select @Canonical = (select @BackupType BackupType, iif(@Platform = N'Windows', lower(@BackupFolder), @BackupFolder) BackupFolder, @BackupCompression BackupCompression,
		@OtherBackupOptions OtherBackupOptions, @RetentionHours RetentionHours, @UseBackupHeader UseBackupHeader for json path, include_null_values, without_array_wrapper);
	select @SettingsHash = convert(varchar(64), hashbytes('SHA2_256', convert(varbinary(max), @Canonical)), 2),
		@GroupLock = N'z.Backup.Run:' + @BackupType + N':' + @RunID;
	begin try
		if applock_mode('public', @GroupLock, 'Session') <> 'NoLock'
			throw 50000, 'This session already participates in this backup run.', 1;
		begin tran;
		exec @LockResult = sys.sp_getapplock @Resource = N'z.Backup.Register', @LockMode = 'Exclusive', @LockOwner = 'Transaction', @LockTimeout = 60000, @DbPrincipal = 'public';
		if @LockResult < 0 throw 50000, 'Could not acquire the backup registration lock.', 1;
		if exists(select * from @DatabaseList t where not exists(select * from z.v_DatabaseBackupStatus v
			where v.BackupType = @BackupType and v.DatabaseID = t.DatabaseID and v.DatabaseName collate Latin1_General_100_BIN2 = t.DatabaseName collate Latin1_General_100_BIN2
				and datalength(v.DatabaseName) = datalength(t.DatabaseName) and v.CreateDate = t.CreateDate))
			throw 50000, 'A selected database changed identity before backup registration.', 1;
		if exists(select * from z.v_DatabaseBackupStatus v inner join @DatabaseList t on t.DatabaseID = v.DatabaseID where v.BackupType = @BackupType and v.MetadataStatus = 'Invalid')
			throw 50000, 'Backup coordination metadata has invalid fields.', 1;
		-- Probe before joining; promoting our own Shared group lock would mask other workers.
		select @OtherWorkers = iif(applock_test('public', @GroupLock, 'Exclusive', 'Session') = 0, 1, 0);
		select @NewBatch = iif(@OtherWorkers = 0 and not exists
			(select * from z.v_DatabaseBackupStatus v inner join @DatabaseList t on t.DatabaseID = v.DatabaseID
				where v.BackupType = @BackupType and v.MetadataStatus = 'Valid' and v.RunID = @RunID and v.EndDate is null), 1, 0);
		if @OtherWorkers = 1 and exists(select * from z.v_DatabaseBackupStatus v inner join @DatabaseList t on t.DatabaseID = v.DatabaseID
			where v.BackupType = @BackupType and v.MetadataStatus = 'Valid' and v.RunID = @RunID and (v.SettingsHash is null or v.SettingsHash <> @SettingsHash))
			throw 50000, 'Active backup workers for this database set must use identical backup settings.', 1;
		if @NewBatch = 1
			update z.v_DatabaseBackupStatus set RunID = @RunID, SettingsHash = @SettingsHash, SessionID = null, StartDate = null, EndDate = null
			where BackupType = @BackupType and DatabaseID in (select DatabaseID from @DatabaseList);
		else if @OtherWorkers = 0
			-- Correcting inactive settings preserves assignments and already completed work.
			update z.v_DatabaseBackupStatus set SettingsHash = @SettingsHash
			where BackupType = @BackupType and MetadataStatus = 'Valid' and RunID = @RunID and DatabaseID in (select DatabaseID from @DatabaseList);
		exec @LockResult = sys.sp_getapplock @Resource = @GroupLock, @LockMode = 'Shared', @LockOwner = 'Session', @LockTimeout = 0, @DbPrincipal = 'public';
		if @LockResult < 0 throw 50000, 'Could not join the backup run.', 1;
		select @GroupHeld = 1;
		commit;
		while @Pending = 1
		begin
			declare c cursor local fast_forward for
				select DatabaseName, StandardizedDatabaseName, DatabaseID, CreateDate
				from @DatabaseList
				order by DataSizeMB asc
			open c
			fetch next from c into @DatabaseName, @StandardizedDatabaseName, @DatabaseID, @DatabaseCreateDate
			while @@fetch_status = 0
			begin
				select @DatabaseLock = N'z.Backup.Database:' + convert(nvarchar(20), @DatabaseID)
					+ iif(@BackupType = 'LOG', N':LOG', N':DATA');
				exec @LockResult = sys.sp_getapplock @Resource = @DatabaseLock, @LockMode = 'Exclusive', @LockOwner = 'Session', @LockTimeout = 0, @DbPrincipal = 'public';
				if @LockResult >= 0
				begin
					select @DatabaseLockHeld = 1, @HasWork = 0;
					if not exists(select * from sys.databases where database_id = @DatabaseID and name = @DatabaseName and create_date = @DatabaseCreateDate)
						throw 50000, 'A selected database changed identity during backup execution.', 1;
					begin tran;
					exec @LockResult = sys.sp_getapplock @Resource = N'z.Backup.Register', @LockMode = 'Exclusive', @LockOwner = 'Transaction', @LockTimeout = 60000, @DbPrincipal = 'public';
					if @LockResult < 0 throw 50000, 'Could not acquire the backup claim lock.', 1;
					if exists(select * from z.v_DatabaseBackupStatus where BackupType = @BackupType and DatabaseID = @DatabaseID and MetadataStatus = 'Invalid')
						throw 50000, 'Backup coordination metadata has invalid fields.', 1;
					if exists(select * from z.v_DatabaseBackupStatus where BackupType = @BackupType and DatabaseID = @DatabaseID and MetadataStatus = 'Valid'
						and RunID = @RunID and (SettingsHash is null or SettingsHash <> @SettingsHash))
						throw 50000, 'Backup settings changed during this run.', 1;
					select @StartDate = sysutcdatetime();
					update z.v_DatabaseBackupStatus set SessionID = @@spid, StartDate = @StartDate, EndDate = null
					where BackupType = @BackupType and DatabaseID = @DatabaseID and DatabaseName collate Latin1_General_100_BIN2 = @DatabaseName collate Latin1_General_100_BIN2
						and datalength(DatabaseName) = datalength(@DatabaseName) and CreateDate = @DatabaseCreateDate
						and MetadataStatus = 'Valid' and RunID = @RunID and SettingsHash = @SettingsHash and EndDate is null;
					select @HasWork = iif(exists(select * from z.v_DatabaseBackupStatus where BackupType = @BackupType and DatabaseID = @DatabaseID
						and MetadataStatus = 'Valid' and RunID = @RunID and SettingsHash = @SettingsHash and SessionID = @@spid and StartDate = @StartDate and EndDate is null), 1, 0);
					commit;
					if @HasWork = 1
					begin
						select @RawPath = @BackupFolder + iif(@@servername like '%\%', replace(@@servername, '\', @FolderSeparator), @@servername + @FolderSeparator + 'MSSQLSERVER')
							+ @FolderSeparator + @StandardizedDatabaseName;
						if len(@RawPath) + len(@StandardizedDatabaseName) + 50 > 4000 or @StandardizedDatabaseName in (N'.', N'..')
							throw 50000, 'Generated database backup path is invalid or too long.', 1;
						if @Platform = N'Windows' and exists(select * from string_split(@RawPath, N'\') where right(value, 1) in (N'.', N' '))
							throw 50000, 'Generated database backup folder contains a Windows path alias.', 1;
						select @Character = 1;
						while @Character <= datalength(@RawPath) / 2
						begin
							if unicode(substring(@RawPath, @Character, 1)) < 32 throw 50000, 'Generated database backup folder contains control characters.', 1;
							select @Character += 1;
						end
						select @DatabaseBackupFolder = @RawPath, @BackupPath = @RawPath + @FolderSeparator + @BackupType + @FolderSeparator;
						select @BackupFileName = @BackupPath + @StandardizedDatabaseName + '_' + format(sysdatetime(), 'yyyyMMdd_HHmmss_ffffff', 'en-US')
							+ case @BackupType when 'FULL' then N'.bak' when 'DIFF' then N'.diff' else N'.trn' end;
						if datalength(@BackupFileName) > 518 throw 50000, 'Generated backup filename exceeds the native 259-character path limit.', 1;
						select @LockName = N'z.Backup:' + convert(nvarchar(64), hashbytes('SHA2_256', convert(varbinary(max),
							convert(nvarchar(max), convert(nvarchar(20), db_id(@DatabaseName))) + N'|' + iif(@Platform = N'Windows', lower(@DatabaseBackupFolder), @DatabaseBackupFolder))), 2);
						exec @LockResult = sys.sp_getapplock @Resource = @LockName, @LockMode = 'Shared', @LockOwner = 'Session', @LockTimeout = 60000, @DbPrincipal = 'public';
						if @LockResult < 0 throw 50000, 'Could not acquire shared access to the database backup folder.', 1;
						select @LockHeld = 1;
						if not exists(select * from sys.dm_os_file_exists(@BackupPath) where file_is_a_directory = 1)
						begin
							exec @DirectoryResult = master.sys.xp_create_subdir @BackupPath;
							if @DirectoryResult <> 0 or @DirectoryResult is null or not exists(select * from sys.dm_os_file_exists(@BackupPath) where file_is_a_directory = 1)
								throw 50000, 'Backup directory creation failed.', 1;
						end
						if @BackupType = 'FULL'
						begin
							select @SQL =	'backup database '   + quotename(@DatabaseName) + ' to disk = N''' + replace(@BackupFileName, N'''', N'''''') + ''' with '
						end
						else if @BackupType = 'DIFF'
						begin
							select @SQL =	'backup database '   + quotename(@DatabaseName) + ' to disk = N''' + replace(@BackupFileName, N'''', N'''''') + ''' with differential, '
						end
						else if @BackupType = 'LOG'
						begin
							select @SQL =	'backup log '   + quotename(@DatabaseName) + ' to disk = N''' + replace(@BackupFileName, N'''', N'''''') + ''' with '
						end
						select @SQL = @SQL + iif(@BackupCompression = 1, 'compression', 'no_compression')
						if @OtherBackupOptions is not null
							select @SQL = @SQL + ', ' + @OtherBackupOptions
						print @SQL
						-- Native backup starts after the claim is committed.
						exec(@SQL)
						begin tran;
						exec @LockResult = sys.sp_getapplock @Resource = N'z.Backup.Register', @LockMode = 'Exclusive', @LockOwner = 'Transaction', @LockTimeout = 60000, @DbPrincipal = 'public';
						if @LockResult < 0 throw 50000, 'Could not acquire the backup completion lock.', 1;
						if exists(select * from z.v_DatabaseBackupStatus where BackupType = @BackupType and DatabaseID = @DatabaseID and MetadataStatus = 'Invalid')
							throw 50000, 'Backup coordination metadata has invalid fields.', 1;
						update z.v_DatabaseBackupStatus set EndDate = sysutcdatetime()
						where BackupType = @BackupType and DatabaseID = @DatabaseID and DatabaseName collate Latin1_General_100_BIN2 = @DatabaseName collate Latin1_General_100_BIN2
							and datalength(DatabaseName) = datalength(@DatabaseName) and CreateDate = @DatabaseCreateDate
							and MetadataStatus = 'Valid' and RunID = @RunID and SettingsHash = @SettingsHash and SessionID = @@spid and StartDate = @StartDate and EndDate is null;
						commit;

						-- Release Shared before requesting Exclusive; never promote a backup folder lock.
						exec sys.sp_releaseapplock @Resource = @LockName, @LockOwner = 'Session', @DbPrincipal = 'public';
						select @LockHeld = 0;
						if @RetentionHours is not null
						begin
							exec @LockResult = sys.sp_getapplock @Resource = @LockName, @LockMode = 'Exclusive', @LockOwner = 'Session', @LockTimeout = 0, @DbPrincipal = 'public';
							if @LockResult >= 0
							begin
								select @LockHeld = 1;
								exec z.usp_CleanupDatabaseBackups @DatabaseName = @DatabaseName, @DatabaseBackupFolder = @DatabaseBackupFolder,
									@RetentionHours = @RetentionHours, @UseBackupHeader = @UseBackupHeader;
								exec sys.sp_releaseapplock @Resource = @LockName, @LockOwner = 'Session', @DbPrincipal = 'public';
								select @LockHeld = 0;
							end
							else if @LockResult = -1 print 'Backup completed; cleanup deferred because the database backup folder is busy.';
							else throw 50000, 'Could not acquire the backup cleanup lock.', 1;
						end
					end
					exec sys.sp_releaseapplock @Resource = @DatabaseLock, @LockOwner = 'Session', @DbPrincipal = 'public';
					select @DatabaseLockHeld = 0;
				end
				else if @LockResult <> -1 throw 50000, 'Could not acquire the database backup execution lock.', 1;
				fetch next from c into @DatabaseName, @StandardizedDatabaseName, @DatabaseID, @DatabaseCreateDate
			end
			close c
			deallocate c
			begin tran;
			exec @LockResult = sys.sp_getapplock @Resource = N'z.Backup.Register', @LockMode = 'Exclusive', @LockOwner = 'Transaction', @LockTimeout = 60000, @DbPrincipal = 'public';
			if @LockResult < 0 throw 50000, 'Could not acquire the backup pending-work lock.', 1;
			if exists(select * from z.v_DatabaseBackupStatus v inner join @DatabaseList t on t.DatabaseID = v.DatabaseID where v.BackupType = @BackupType and v.MetadataStatus = 'Invalid')
				throw 50000, 'Backup coordination metadata has invalid fields.', 1;
			if exists(select * from z.v_DatabaseBackupStatus v inner join @DatabaseList t on t.DatabaseID = v.DatabaseID
				where v.BackupType = @BackupType and v.MetadataStatus = 'Valid' and v.RunID = @RunID and (v.SettingsHash is null or v.SettingsHash <> @SettingsHash))
				throw 50000, 'Backup settings changed during this run.', 1;
			select @Pending = iif(exists(select * from z.v_DatabaseBackupStatus v inner join @DatabaseList t on t.DatabaseID = v.DatabaseID
				where v.BackupType = @BackupType and v.MetadataStatus = 'Valid' and v.RunID = @RunID and v.EndDate is null), 1, 0);
			commit;
			if @Pending = 1 waitfor delay '00:00:00.250';
		end
		exec sys.sp_releaseapplock @Resource = @GroupLock, @LockOwner = 'Session', @DbPrincipal = 'public';
		select @GroupHeld = 0;
	end try
	begin catch
		if @@trancount > 0 rollback;
		if @LockHeld = 1 exec sys.sp_releaseapplock @Resource = @LockName, @LockOwner = 'Session', @DbPrincipal = 'public';
		if @DatabaseLockHeld = 1 exec sys.sp_releaseapplock @Resource = @DatabaseLock, @LockOwner = 'Session', @DbPrincipal = 'public';
		if @GroupHeld = 1 exec sys.sp_releaseapplock @Resource = @GroupLock, @LockOwner = 'Session', @DbPrincipal = 'public';
		throw;
	end catch
end
go
