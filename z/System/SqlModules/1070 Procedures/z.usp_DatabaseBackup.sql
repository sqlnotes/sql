create or alter procedure z.usp_DatabaseBackup
(
	@Databases nvarchar(max) = 'AllDatabases', --'AllDatabases', 'UserDatabases', 'SystemDatabases', 'Database1,Dabase2...'
	@BackupType nvarchar(50) = 'Full', --'Full, Log, Diff'
	@BackupFolder nvarchar(max) = null, --Folder used to save the backup. 
	@BackupCompression bit = 1,
	@OtherBackupOptions nvarchar(max) = null,-- 'stats = 1',
	@RetentionHours int = 30
)
as
begin
	set nocount on
	declare @BackupPath nvarchar(4000), @SQL nvarchar(max), @DatabaseName nvarchar(128), @StandardizedDatabaseName nvarchar(128), @FolderSeparator varchar(1), @BackupFileName nvarchar(max)
	if @BackupType not in ('Full', 'Log', 'Diff')
	begin
		raiserror('@BackupType must be Full, Log, or Diff', 16, 1)
		return
	end
	if @BackupCompression is null
		select @BackupCompression = isnull((select cast(value as int) from sys.configurations where name = 'backup compression default'), 0)
	declare @DatabaseList table(
								DatabaseName nvarchar(128) primary key, 
								StandardizedDatabaseName nvarchar(128) not null,
								DataSizeMB bigint
							)
	insert into @DatabaseList(DatabaseName, StandardizedDatabaseName, DataSizeMB)
		select	d.name, 
				replace(translate(d.name, '<>:"/\?*', '        '), ' ', '_'),
				sum(m.size) *8/1024
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
		group by d.name
	if not exists(select * from @DatabaseList)
	begin
		print 'No databases to be backup.'
		return
	end
	if @BackupFolder is null
	begin
		select @BackupFolder = cast(serverproperty('InstanceDefaultBackupPath') as nvarchar(max))
	end
	if @BackupFolder is null
	begin
		raiserror('Please specify backup folder', 16, 1)
		return
	end

	select @BackupFolder = rtrim(@BackupFolder), @FolderSeparator = iif(@@version like '%linux%', '/', '\'), @BackupType = upper(@BackupType), @RetentionHours = abs(@RetentionHours)
	if right(@BackupFolder, 1) in ('/', '\')
		select @BackupFolder = left(@BackupFolder, len(@BackupFolder) -1)
	
	if right(@BackupFolder, 1) <> @FolderSeparator
		select @BackupFolder = @BackupFolder + @FolderSeparator
	
	begin try
	declare c cursor local for
		select DatabaseName, StandardizedDatabaseName
		from @DatabaseList
		order by DataSizeMB asc
	open c
	fetch next from c into @DatabaseName, @StandardizedDatabaseName
	while @@fetch_status = 0
	begin
		select @BackupPath = @BackupFolder + iif(@@servername like '%\%', replace(@@servername, '\', @FolderSeparator), @@servername + '\MSSQLSERVER') + @FolderSeparator 
							+ @StandardizedDatabaseName + @FolderSeparator 
							+ @BackupType + @FolderSeparator
		if not exists(select * from sys.dm_os_file_exists(@BackupPath) where file_is_a_directory = 1)
		begin
			exec master.sys.xp_create_subdir @BackupPath
		end
		select @BackupFileName = replace(@BackupPath + @StandardizedDatabaseName + '_' + format(sysdatetime(), 'yyyyMMdd_HHmmss_') + left(cast(datepart(nanosecond, sysdatetime()) as varchar), 7), '''', '''''')
		if @BackupType = 'FULL'
		begin
			select @SQL =	'backup database '   + quotename(@DatabaseName) + ' to disk = ''' + @BackupFileName + '.bak'' with '
		end
		else if @BackupType = 'DIFF'
		begin
			select @SQL =	'backup database '   + quotename(@DatabaseName) + ' to disk = ''' + @BackupFileName + '.diff'' with differential, '
		end
		else if @BackupType = 'LOG'
		begin
			select @SQL =	'backup log '   + quotename(@DatabaseName) + ' to disk = ''' + @BackupFileName + '.log'' with '
		end
		select @SQL = @SQL + iif(@BackupCompression = 1, 'compression', 'no_compression')
		if @OtherBackupOptions is not null
			select @SQL = @SQL + ', ' + @OtherBackupOptions
		
		exec(@SQL)

		declare c1 cursor local for
			select bf.physical_device_name
			from msdb.dbo.backupset bs
				left outer join msdb.dbo.backupmediafamily bf ON bs.media_set_id = bf.media_set_id
				inner join msdb.dbo.backupmediaset bms ON bs.media_set_id = bms.media_set_id
				cross apply sys.dm_os_file_exists(bf.physical_device_name) f
			where bms.software_name = 'Microsoft SQL Server'
				and bs.type = case @BackupType when 'FULL' then 'D' when 'DIFF' then 'I' when 'LOG' then 'L' end
				and bs.database_name = @DatabaseName
				and bs.Backup_Finish_Date < dateadd(hour, - @RetentionHours, getdate())
				and f.file_exists = 1
		open c1
		fetch next from c1 into @BackupFileName
		while @@fetch_status = 0
		begin
			exec master..xp_delete_file 0, @BackupFileName
			fetch next from c1 into @BackupFileName
		end
		close c1
		deallocate c1
		fetch next from c into @DatabaseName, @StandardizedDatabaseName
	end
	close c
	deallocate c
	end try
	begin catch
		if @@trancount > 0
			rollback;
		throw;
	end catch
end
go
--exec z.usp_DatabaseBackup @Databases = 'model,master,test2', @OtherBackupOptions = null
--select * from sys.master_files
