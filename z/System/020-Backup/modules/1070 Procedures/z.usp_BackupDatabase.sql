create or alter procedure z.usp_BackupDatabase
(
	@Databases nvarchar(max) = 'AllDatabases', --'AllDatabases', 'UserDatabases', 'SystemDatabases', 'Database1,Dabase2...'
	@BackupType nvarchar(50) = 'Full', --'Full, Log, Diff'
	@BackupFolder nvarchar(4000) = null, --Filesystem folder or Azure/S3 URL prefix.
	@BackupCompression bit = 1,
	@OtherBackupOptions nvarchar(max) = null,-- 'stats = 1',
	@ServerName sysname = null --Backup path label; NULL uses @@servername.
)
as
begin
	set nocount on;
	if @@trancount <> 0
	begin
		set xact_abort off;
		throw 50000, 'Backup cannot run inside a transaction.', 1;
	end
	set xact_abort on;
	declare @BackupPath nvarchar(4000), @SQL nvarchar(max), @DatabaseName nvarchar(128), @StandardizedDatabaseName nvarchar(128), @FolderSeparator varchar(1),
			@BackupFileName nvarchar(4000), @RawPath nvarchar(max), @Platform nvarchar(256), @DirectoryResult int,
			@IsUrl bit, @BackupDevice varchar(4), @IsReadOnly bit,
			@EffectiveOptions nvarchar(max), @OptionSeparator nvarchar(4) = nchar(13) + nchar(10) + N', ';
	select @BackupType = upper(trim(@BackupType)), @ServerName = coalesce(@ServerName, @@servername);

	if @BackupType is null or @BackupType not in ('FULL', 'LOG', 'DIFF')
		throw 50000, '@BackupType must be Full, Log, or Diff', 1;


	if nullif(trim(translate(@OtherBackupOptions, nchar(9) + nchar(10) + nchar(11) + nchar(12) + nchar(13), N'     ')), N'') is null
		select @OtherBackupOptions = null;

	if @BackupCompression is null
	begin
		select @BackupCompression = isnull((select cast(value as int) from sys.configurations where name = 'backup compression default'), 0)
	end
	declare @Options table(OptionID int identity primary key, OptionName nvarchar(128) collate Latin1_General_100_BIN2, OptionText nvarchar(max));
	if @OtherBackupOptions is not null
	begin
		-- Split only top-level commas. Quoted values, nested lists and comments remain intact.
		declare @OptionInput nvarchar(max) = @OtherBackupOptions + nchar(13) + nchar(10) + N',',
			@Position int = 1, @OptionStart int = 1, @InputLength int, @Depth int = 0, @CommentDepth int = 0,
			@LineComment bit = 0, @Quote nchar(1), @Character nchar(1), @Next nchar(1),
			@OptionName nvarchar(128) = N'', @NameDone bit = 0, @OptionText nvarchar(max);
		select @InputLength = len(@OptionInput);
		while @Position <= @InputLength
		begin
			select @Character = substring(@OptionInput, @Position, 1), @Next = substring(@OptionInput, @Position + 1, 1);
			if @LineComment = 1
			begin
				if @Character in (nchar(13), nchar(10)) select @LineComment = 0;
			end
			else if @CommentDepth > 0
			begin
				if @Character = N'/' and @Next = N'*' select @CommentDepth += 1, @Position += 1;
				else if @Character = N'*' and @Next = N'/' select @CommentDepth -= 1, @Position += 1;
			end
			else if @Quote is not null
			begin
				if @Character = @Quote
				begin
					if @Next = @Quote select @Position += 1;
					else select @Quote = null;
				end
			end
			else if @Character = N'-' and @Next = N'-'
				select @LineComment = 1, @Position += 1, @NameDone = iif(@OptionName = N'', 0, 1);
			else if @Character = N'/' and @Next = N'*'
				select @CommentDepth = 1, @Position += 1, @NameDone = iif(@OptionName = N'', 0, 1);
			else if @Character in (N'''', N'"', N'[')
				select @Quote = iif(@Character = N'[', N']', @Character), @NameDone = 1;
			else if @Character = N'('
				select @Depth += 1, @NameDone = 1;
			else if @Character = N')'
			begin
				select @Depth -= 1;
				if @Depth < 0 throw 50000, 'Malformed @OtherBackupOptions: unmatched parenthesis.', 1;
			end
			else if @Character = N',' and @Depth = 0
			begin
				if @OptionName = N'' throw 50000, 'Malformed @OtherBackupOptions: an option name is missing.', 1;
				select @OptionText = trim(substring(@OptionInput, @OptionStart, @Position - @OptionStart - iif(@Position = @InputLength, 2, 0))),
					@OptionName = upper(@OptionName collate Latin1_General_100_CI_AS);
				select @OptionName = case @OptionName
					when N'NO_COMPRESSION' then N'COMPRESSION' when N'NOINIT' then N'INIT'
					when N'NOFORMAT' then N'FORMAT' when N'NO_CHECKSUM' then N'CHECKSUM'
					when N'NOSKIP' then N'SKIP' when N'NOREWIND' then N'REWIND'
					when N'NOUNLOAD' then N'UNLOAD' when N'CONTINUE_AFTER_ERROR' then N'STOP_ON_ERROR'
					else @OptionName end;
				insert into @Options(OptionName, OptionText) values(@OptionName, @OptionText);
				select @OptionStart = @Position + 1, @OptionName = N'', @NameDone = 0;
			end
			else if @NameDone = 0
			begin
				if @Character collate Latin1_General_100_BIN2 like N'[A-Za-z0-9_]'
				begin
					if len(@OptionName) = 128 throw 50000, 'Malformed @OtherBackupOptions: option name is too long.', 1;
					select @OptionName += @Character;
				end
				else if @OptionName <> N'' or @Character not in (N' ', nchar(9), nchar(10), nchar(11), nchar(12), nchar(13))
					select @NameDone = 1;
			end
			select @Position += 1;
		end
		if @Quote is not null or @Depth <> 0 or @CommentDepth <> 0
			throw 50000, 'Malformed @OtherBackupOptions: unclosed quote, bracket, parenthesis or comment.', 1;
		-- Last user occurrence wins, including opposing switches in the same option group.
		delete t from @Options t where exists(select * from @Options s where s.OptionName = t.OptionName and s.OptionID > t.OptionID);
		select @OtherBackupOptions = string_agg(OptionText, @OptionSeparator) within group(order by OptionID) from @Options;
	end

	declare @DatabaseList table(
								DatabaseName nvarchar(128) primary key,
							StandardizedDatabaseName nvarchar(128) not null, DataSizeMB bigint, IsReadOnly bit
								)

	insert into @DatabaseList(DatabaseName, StandardizedDatabaseName, DataSizeMB, IsReadOnly)
		select	d.name,
				replace(translate(d.name, N'<>:"/\?*' + nchar(9) + nchar(10) + nchar(11) + nchar(12) + nchar(13), '             '), ' ', '_'),
				sum(cast(m.size as bigint)) * 8/1024, d.is_read_only
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
		group by d.name, d.is_read_only
	if @@rowcount = 0
	begin
		print 'No databases to be backup.'
		return
	end

	if @BackupFolder is null
	begin
		select @BackupFolder = nullif(trim(cast(serverproperty('InstanceDefaultBackupPath') as nvarchar(4000))), '')
	end
	select @BackupFolder = nullif(trim(@BackupFolder), '')
	if @BackupFolder is null
		throw 50000, 'Please specify backup folder', 1;

	select @IsUrl = iif(lower(left(@BackupFolder, 8)) = N'https://' or lower(left(@BackupFolder, 5)) = N's3://', 1, 0);
	if lower(left(@BackupFolder, 5)) = N's3://' and convert(int, serverproperty('ProductMajorVersion')) < 16
		throw 50000, 'S3 backup destinations require SQL Server 2022 or later.', 1;
	if @IsUrl = 1
		select @FolderSeparator = '/', @BackupDevice = 'URL';
	else
	begin
		select @Platform = host_platform from sys.dm_os_host_info;
		if @Platform is null or @Platform not in (N'Windows', N'Linux')
			throw 50000, 'Unsupported backup filesystem platform.', 1;
		select @FolderSeparator = iif(@Platform = N'Linux', '/', '\'), @BackupDevice = 'DISK';
		if @Platform = N'Windows' select @BackupFolder = replace(@BackupFolder, N'/', N'\');
	end
	while right(@BackupFolder, 1) = @FolderSeparator and len(@BackupFolder) > 1
		select @BackupFolder = left(@BackupFolder, len(@BackupFolder) -1)



	if right(@BackupFolder, 1) <> @FolderSeparator
		select @BackupFolder = @BackupFolder + @FolderSeparator

	begin try
		declare c cursor local fast_forward for
			select DatabaseName, StandardizedDatabaseName, IsReadOnly from @DatabaseList order by DataSizeMB asc;
		open c;
		fetch next from c into @DatabaseName, @StandardizedDatabaseName, @IsReadOnly;
		while @@fetch_status = 0
		begin
			select @RawPath = @BackupFolder + iif(@ServerName like '%\%', replace(@ServerName, '\', @FolderSeparator), @ServerName + @FolderSeparator + 'MSSQLSERVER')
				+ @FolderSeparator + @StandardizedDatabaseName;
			select @BackupPath = @RawPath + @FolderSeparator + @BackupType + @FolderSeparator;
			select @BackupFileName = @BackupPath + @StandardizedDatabaseName + '_' + format(sysdatetime(), 'yyyyMMdd_HHmmss_ffffff', 'en-US')
				+ case @BackupType when 'FULL' then N'.bak' when 'DIFF' then N'.diff' else N'.trn' end;
			if @IsUrl = 0
			begin
				if not exists(select * from sys.dm_os_file_exists(@BackupPath) where file_is_a_directory = 1)
				begin
					exec @DirectoryResult = master.sys.xp_create_subdir @BackupPath;
					if @DirectoryResult <> 0 or @DirectoryResult is null or not exists(select * from sys.dm_os_file_exists(@BackupPath) where file_is_a_directory = 1)
						throw 50000, 'Backup directory creation failed.', 1;
				end
			end
			if @BackupType in ('FULL', 'DIFF')
				select @SQL = 'backup database ' + quotename(@DatabaseName) + ' to ' + @BackupDevice + ' = N''' + replace(@BackupFileName, N'''', N'''''') + ''' with ';
			else
				select @SQL = 'backup log ' + quotename(@DatabaseName) + ' to ' + @BackupDevice + ' = N''' + replace(@BackupFileName, N'''', N'''''') + ''' with ';
			select @EffectiveOptions = @OtherBackupOptions;
			if not exists(select * from @Options where OptionName = N'COMPRESSION')
				select @EffectiveOptions = iif(@BackupCompression = 1, N'compression', N'no_compression') + coalesce(@OptionSeparator + @EffectiveOptions, N'');
			if @BackupType = 'DIFF' and not exists(select * from @Options where OptionName = N'DIFFERENTIAL')
				select @EffectiveOptions = N'differential' + @OptionSeparator + @EffectiveOptions;
			if @IsReadOnly = 1 and not exists(select * from @Options where OptionName = N'COPY_ONLY')
				select @EffectiveOptions = N'copy_only' + @OptionSeparator + @EffectiveOptions;
			select @SQL += @EffectiveOptions;
			print @SQL;
			exec(@SQL);
			fetch next from c into @DatabaseName, @StandardizedDatabaseName, @IsReadOnly;
		end
		close c;
		deallocate c;
	end try
	begin catch
		throw;
	end catch
end
go
