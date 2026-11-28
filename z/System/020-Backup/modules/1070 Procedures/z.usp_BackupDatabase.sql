/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/020-Backup/modules/1070%20Procedures/z.usp_BackupDatabase.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/020-Backup/docs/reference/z.usp_BackupDatabase.md

Backs up selected databases sequentially to filesystem or supported URL destinations.
*/
create or alter procedure z.usp_BackupDatabase
(
	@Databases nvarchar(max) = 'AllDatabases', -- Group keyword, comma-separated names or JSON array.
	@BackupType nvarchar(50) = 'Full', -- Full, Log, Diff
	@BackupFolder nvarchar(4000) = null, -- Filesystem folder or Azure/S3 URL prefix.
	@BackupCompression bit = 1,
	@OtherBackupOptions nvarchar(max) = null, -- e.g. 'stats = 1'
	@ServerName sysname = null, -- Backup path label; NULL uses @@servername.
	@BackupFileNameFormat nvarchar(4000) = N'{ServerName}${InstanceName}${DatabaseName}_{yyyyMMdd}_{HHmmssfffffff}',
	@FullBackupIfNeeded bit = 1,
	@CopyOnly bit = 0,
	@CreateServerInstanceFolder bit = 1,
	@CreateBackupTypeFolder bit = 1,
	@RetentionHours int = null
)
as
begin
	set nocount, xact_abort on;
	if @@trancount > 0 or @@options & 2 = 2
		throw 50000, 'Backup cannot run inside a transaction or implicit transactions.', 1;

	declare	@DatabaseBackupFolder nvarchar(max), @BackupPath nvarchar(max), @SQL nvarchar(max), @DatabaseName nvarchar(128), @StandardizedDatabaseName nvarchar(128),
			@FolderSeparator varchar(1), @BackupFileName nvarchar(max), @Platform nvarchar(256), @DirectorySql nvarchar(max),
			@DirectoryAttempt int, @IsUrl bit, @BackupDevice varchar(4), @BackupExtension varchar(15), @IsReadOnly bit,
			@EffectiveBackupType nvarchar(50), @NeedsFull bit, @Proc nvarchar(276),
			@DifferentialBaseLSN numeric(25,0), @DifferentialBaseGUID uniqueidentifier, @PreviousBaseGUID uniqueidentifier,
			@LastLogBackupLSN numeric(25,0), @EffectiveOptions nvarchar(max), @OptionSeparator nvarchar(4) = nchar(13) + nchar(10) + N', ',
			@ServerLabel nvarchar(128), @InstanceLabel nvarchar(128), @InstanceSeparator int, @Stamp nvarchar(27), @FormattedName nvarchar(max),
			@RunBatchID uniqueidentifier = newid(), @FailedCount int = 0, @FirstErrorMessage nvarchar(512),
			@StepStartTime datetime2(3), @StepEndTime datetime2(3), @StepIsCopyOnly bit, @ErrorNumber int, @ErrorMessage nvarchar(512);

	-- The primary file identifies the database base; newly added secondary files may have none.
	declare	@ReadBaseSql nvarchar(max) = N'select @BaseLSN = differential_base_lsn, @BaseGUID = differential_base_guid from sys.database_files where file_id = 1 and type = 0;',
			@ReadBaseParameters nvarchar(100) = N'@BaseLSN numeric(25,0) output, @BaseGUID uniqueidentifier output';

	select	@BackupType = upper(trim(@BackupType)),
			@ServerName = nullif(trim(isnull(nullif(trim(@ServerName), N''), @@servername)), N''),
			@CreateServerInstanceFolder = isnull(@CreateServerInstanceFolder, 1),
			@CreateBackupTypeFolder = isnull(@CreateBackupTypeFolder, 1);

	if @BackupType is null or @BackupType not in ('FULL', 'LOG', 'DIFF')
		throw 50000, '@BackupType must be Full, Log, or Diff', 1;

	if @RetentionHours <= 0
		throw 50000, '@RetentionHours must be positive or NULL.', 1;

	if @ServerName is null
		throw 50000, 'ServerName must identify a server and an optional nonempty instance name.', 1;

	if nullif(trim(@BackupFileNameFormat), N'') is null
		select	@BackupFileNameFormat = N'{ServerName}${InstanceName}${DatabaseName}_{yyyyMMdd}_{HHmmssfffffff}';

	select	@InstanceSeparator = charindex(N'\', @ServerName);
	select	@ServerLabel = z.fn_StandardizeFileName(nullif(trim(iif(@InstanceSeparator = 0, @ServerName, left(@ServerName, iif(@InstanceSeparator > 0, @InstanceSeparator - 1, 0)))), N'')),
			@InstanceLabel = z.fn_StandardizeFileName(nullif(trim(iif(@InstanceSeparator = 0, N'MSSQLSERVER', substring(@ServerName, @InstanceSeparator + 1, 128))), N''));
	if @ServerLabel is null or @InstanceLabel is null
		throw 50000, 'ServerName must identify a server and an optional nonempty instance name.', 1;

	if nullif(trim(translate(@OtherBackupOptions, nchar(9) + nchar(10) + nchar(11) + nchar(12) + nchar(13), N'     ')), N'') is null
		select	@OtherBackupOptions = null;

	-- Strip options owned by procedure parameters while preserving all remaining top-level clauses verbatim.
	if @OtherBackupOptions is not null
	begin
		declare	@OptPos int = 1, @OptLen int = datalength(@OtherBackupOptions) / 2, @ClauseStart int = 1,
				@InSingleQuote bit = 0, @InBracket bit = 0, @InLineComment bit = 0, @BlockCommentDepth int = 0, @ParenDepth int = 0,
				@HasStrippedOption bit = 0, @KeptOptions nvarchar(max) = N'',
				@TrimStart int, @TrimEnd int, @Clause nvarchar(max), @CleanPos int, @CleanLen int, @TokenStart int,
				@Token nvarchar(128), @Ch nchar(1), @NextCh nchar(1);

		while @OptPos <= @OptLen + 1
		begin
			select	@Ch = iif(@OptPos <= @OptLen, substring(@OtherBackupOptions, @OptPos, 1), null),
					@NextCh = iif(@OptPos < @OptLen, substring(@OtherBackupOptions, @OptPos + 1, 1), null);

			if @InLineComment = 1
			begin
				if @Ch in (nchar(10), nchar(13)) or @OptPos > @OptLen
					select	@InLineComment = 0;
				select	@OptPos += 1;
				continue;
			end
			if @BlockCommentDepth > 0
			begin
				if @Ch = N'/' and @NextCh = N'*'
					select	@BlockCommentDepth += 1, @OptPos += 2;
				else if @Ch = N'*' and @NextCh = N'/'
					select	@BlockCommentDepth -= 1, @OptPos += 2;
				else
					select	@OptPos += 1;
				continue;
			end
			if @InSingleQuote = 1
			begin
				if @Ch = N'''' and @NextCh = N''''
					select	@OptPos += 2;
				else if @Ch = N''''
					select	@InSingleQuote = 0, @OptPos += 1;
				else
					select	@OptPos += 1;
				continue;
			end
			if @InBracket = 1
			begin
				if @Ch = N']' and @NextCh = N']'
					select	@OptPos += 2;
				else if @Ch = N']'
					select	@InBracket = 0, @OptPos += 1;
				else
					select	@OptPos += 1;
				continue;
			end

			if @OptPos > @OptLen or (@Ch = N',' and @ParenDepth = 0)
			begin
				select	@TrimStart = @ClauseStart, @TrimEnd = @OptPos - 1;
				while @TrimStart <= @TrimEnd and unicode(substring(@OtherBackupOptions, @TrimStart, 1)) in (9, 10, 11, 12, 13, 32)
					select	@TrimStart += 1;
				while @TrimEnd >= @TrimStart and unicode(substring(@OtherBackupOptions, @TrimEnd, 1)) in (9, 10, 11, 12, 13, 32)
					select	@TrimEnd -= 1;

				if @TrimStart <= @TrimEnd
				begin
					select	@Clause = substring(@OtherBackupOptions, @TrimStart, @TrimEnd - @TrimStart + 1),
							@CleanPos = 1, @CleanLen = @TrimEnd - @TrimStart + 1, @Token = N'';
					while @CleanPos <= @CleanLen
					begin
						select	@Ch = substring(@Clause, @CleanPos, 1),
								@NextCh = iif(@CleanPos < @CleanLen, substring(@Clause, @CleanPos + 1, 1), null);
						if unicode(@Ch) in (9, 10, 11, 12, 13, 32)
							select	@CleanPos += 1;
						else if @Ch = N'-' and @NextCh = N'-'
						begin
							select	@CleanPos += 2;
							while @CleanPos <= @CleanLen and unicode(substring(@Clause, @CleanPos, 1)) not in (10, 13)
								select	@CleanPos += 1;
						end
						else if @Ch = N'/' and @NextCh = N'*'
						begin
							select	@CleanPos += 2, @BlockCommentDepth = 1;
							while @CleanPos <= @CleanLen and @BlockCommentDepth > 0
							begin
								if substring(@Clause, @CleanPos, 2) = N'/*'
									select	@BlockCommentDepth += 1, @CleanPos += 2;
								else if substring(@Clause, @CleanPos, 2) = N'*/'
									select	@BlockCommentDepth -= 1, @CleanPos += 2;
								else
									select	@CleanPos += 1;
							end
							select	@BlockCommentDepth = 0;
						end
						else
							break;
					end
					select	@TokenStart = @CleanPos;
					while @CleanPos <= @CleanLen and substring(@Clause, @CleanPos, 1) collate Latin1_General_100_BIN2 like N'[0-9A-Za-z_]'
						select	@CleanPos += 1;
					if @CleanPos > @TokenStart and @CleanPos - @TokenStart <= 32
						select	@Token = lower(substring(@Clause, @TokenStart, @CleanPos - @TokenStart) collate Latin1_General_100_CI_AS);

					if @Token in (N'compression', N'no_compression', N'differential', N'copy_only')
						select	@HasStrippedOption = 1;
					else
						select	@KeptOptions += iif(@KeptOptions = N'', N'', N', ') + @Clause;
				end
				select	@ClauseStart = @OptPos + 1, @OptPos += 1;
				continue;
			end

			if @Ch = N''''
				select	@InSingleQuote = 1, @OptPos += 1;
			else if @Ch = N'['
				select	@InBracket = 1, @OptPos += 1;
			else if @Ch = N'-' and @NextCh = N'-'
				select	@InLineComment = 1, @OptPos += 2;
			else if @Ch = N'/' and @NextCh = N'*'
				select	@BlockCommentDepth = 1, @OptPos += 2;
			else
			begin
				if @Ch = N'('
					select	@ParenDepth += 1;
				else if @Ch = N')' and @ParenDepth > 0
					select	@ParenDepth -= 1;
				select	@OptPos += 1;
			end
		end

		if @HasStrippedOption = 1
			select	@OtherBackupOptions = nullif(@KeptOptions, N'');
	end

	if @BackupCompression is null
		select	@BackupCompression = isnull((select cast(value as int) from sys.configurations where name = 'backup compression default'), 0);

	declare @DatabasesJson nvarchar(max), @DatabasesCsv nvarchar(max);
	if isjson(@Databases) = 1 and left(ltrim(translate(@Databases, nchar(9) + nchar(10) + nchar(13), N'   ')), 1) = N'['
		select	@DatabasesJson = @Databases;
	else if @Databases not in (N'AllDatabases', N'UserDatabases', N'SystemDatabases')
		select	@DatabasesCsv = @Databases;

	declare @DatabaseList table (DatabaseName nvarchar(128) primary key, StandardizedDatabaseName nvarchar(128) not null, DataSizeMB bigint, IsReadOnly bit);

	insert into @DatabaseList (DatabaseName, StandardizedDatabaseName, DataSizeMB, IsReadOnly)
		select	d.name, z.fn_StandardizeFileName(d.name), sum(cast(m.size as bigint)) * 8 / 1024, d.is_read_only
		from sys.databases d
			inner join sys.master_files m on m.database_id = d.database_id
		where d.state_desc not in ('RESTORING', 'RECOVERING', 'RECOVERY_PENDING', 'SUSPECT', 'EMERGENCY')
			and d.name not in ('tempdb')
			and m.type_desc in ('ROWS')
			and (
				@Databases = N'AllDatabases'
				or @Databases = N'UserDatabases' and d.name not in (N'master', N'model', N'msdb')
				or @Databases = N'SystemDatabases' and d.name in (N'master', N'model', N'msdb')
				or exists (select 1 from string_split(@DatabasesCsv, N',') s where trim(s.value) = d.name collate database_default)
				or exists (select 1 from openjson(@DatabasesJson) j where j.type = 1 and j.value = d.name collate database_default and datalength(j.value) = datalength(d.name))
			)
			and (
				@BackupType in ('FULL', 'DIFF')
				or d.recovery_model_desc <> 'SIMPLE'
			)
		group by d.name, d.is_read_only;

	if @@rowcount = 0
	begin
		print 'No databases to be backup.';
		return;
	end

	if @BackupFolder is null
		select	@BackupFolder = nullif(trim(cast(serverproperty('InstanceDefaultBackupPath') as nvarchar(4000))), N'');

	select	@BackupFolder = nullif(trim(@BackupFolder), N'');
	if @BackupFolder is null
		throw 50000, 'Please specify backup folder', 1;

	select	@IsUrl = iif(lower(left(@BackupFolder, 8)) = N'https://' or lower(left(@BackupFolder, 5)) = N's3://', 1, 0);
	if lower(left(@BackupFolder, 5)) = N's3://' and convert(int, serverproperty('ProductMajorVersion')) < 16
		throw 50000, 'S3 backup destinations require SQL Server 2022 or later.', 1;

	if @IsUrl = 1
		select	@FolderSeparator = '/', @BackupDevice = 'URL';
	else
	begin
		select	@Platform = host_platform from sys.dm_os_host_info;
		if @Platform is null or @Platform not in (N'Windows', N'Linux')
			throw 50000, 'Unsupported backup filesystem platform.', 1;
		select	@FolderSeparator = iif(@Platform = N'Linux', '/', '\'), @BackupDevice = 'DISK';
		if @Platform = N'Windows'
			select	@BackupFolder = replace(@BackupFolder, N'/', N'\');
	end

	while right(@BackupFolder, 1) = @FolderSeparator and len(@BackupFolder) > 1
		select	@BackupFolder = left(@BackupFolder, len(@BackupFolder) - 1);

	declare cCommands cursor local static for
		select	DatabaseName, StandardizedDatabaseName, IsReadOnly
		from @DatabaseList
		order by DataSizeMB asc;
	open cCommands;
	fetch next from cCommands into @DatabaseName, @StandardizedDatabaseName, @IsReadOnly;
	while @@fetch_status = 0
	begin
		select	@EffectiveBackupType = @BackupType, @NeedsFull = 0, @BackupFileName = null, @StepStartTime = sysutcdatetime(),
				@StepIsCopyOnly = iif(@BackupType = 'DIFF', 0, iif(@CopyOnly = 1 or @IsReadOnly = 1, 1, 0)),
				@DatabaseBackupFolder = convert(nvarchar(max), @BackupFolder) + iif(right(@BackupFolder, 1) = @FolderSeparator, N'', @FolderSeparator)
							+ iif(@CreateServerInstanceFolder = 1, @ServerLabel + @FolderSeparator + @InstanceLabel + @FolderSeparator, N'')
							+ @StandardizedDatabaseName;
		begin try
			if @FullBackupIfNeeded = 1 and @BackupType in ('DIFF', 'LOG')
			begin
				select	@Proc = quotename(@DatabaseName) + N'.sys.sp_executesql',
						@DifferentialBaseLSN = null, @DifferentialBaseGUID = null, @LastLogBackupLSN = null;
				exec @Proc	@ReadBaseSql, @ReadBaseParameters, @BaseLSN = @DifferentialBaseLSN output, @BaseGUID = @DifferentialBaseGUID output;

				if @BackupType = 'LOG'
					select	@LastLogBackupLSN = last_log_backup_lsn
					from sys.database_recovery_status
					where database_id = db_id(@DatabaseName);

				if (@BackupType = 'DIFF' and (@DifferentialBaseLSN is null or @DifferentialBaseGUID is null))
					or (@BackupType = 'LOG' and @LastLogBackupLSN is null)
					select	@NeedsFull = 1,
							@EffectiveBackupType = 'FULL',
							@StepIsCopyOnly = iif(@CopyOnly = 1 or @IsReadOnly = 1, 1, 0);

				if @NeedsFull = 1 and @IsReadOnly = 1
					throw 50000, 'FullBackupIfNeeded cannot establish a regular full backup under the read-only COPY_ONLY policy.', 1;
				if @NeedsFull = 1 and @CopyOnly = 1
					throw 50000, 'FullBackupIfNeeded requires a regular full backup. Set CopyOnly to 0 to establish the backup base.', 1;
				select	@PreviousBaseGUID = @DifferentialBaseGUID;
			end

			while @EffectiveBackupType is not null
			begin
				select	@StepStartTime = sysutcdatetime(), @BackupFileName = null,
						@Stamp = convert(nvarchar(27), sysutcdatetime(), 121),
						@StepIsCopyOnly = iif(@EffectiveBackupType = 'DIFF', 0, iif(@CopyOnly = 1 or @IsReadOnly = 1, 1, 0)),
						@BackupPath = @DatabaseBackupFolder + @FolderSeparator + iif(@CreateBackupTypeFolder = 1, @EffectiveBackupType + @FolderSeparator, N'');

				select	@FormattedName = replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(
							convert(nvarchar(max), @BackupFileNameFormat) collate Latin1_General_100_BIN2,
							N'{yyyyMMdd}', substring(@Stamp, 1, 4) + substring(@Stamp, 6, 2) + substring(@Stamp, 9, 2)),
							N'{HHmmssfffffff}', substring(@Stamp, 12, 2) + substring(@Stamp, 15, 2) + substring(@Stamp, 18, 2) + substring(@Stamp, 21, 7)),
							N'{HHmmssffffff}', substring(@Stamp, 12, 2) + substring(@Stamp, 15, 2) + substring(@Stamp, 18, 2) + substring(@Stamp, 21, 6)),
							N'{HHmmss}', substring(@Stamp, 12, 2) + substring(@Stamp, 15, 2) + substring(@Stamp, 18, 2)),
							N'{fffffff}', substring(@Stamp, 21, 7)),
							N'{ffffff}', substring(@Stamp, 21, 6)),
							N'{BackupType}', @EffectiveBackupType),
							N'{ServerName}', @ServerLabel),
							N'{InstanceName}', @InstanceLabel),
							N'{DatabaseName}', @StandardizedDatabaseName);

				select	@BackupExtension = case @EffectiveBackupType
												when 'FULL' then iif(@StepIsCopyOnly = 1, '.copyonly.bak', '.bak')
												when 'DIFF' then '.diff'
												else iif(@StepIsCopyOnly = 1, '.copyonly.trn', '.trn')
											end;
				select	@BackupFileName = @BackupPath + z.fn_StandardizeFileName(@FormattedName) + @BackupExtension;

				if @IsUrl = 0
				begin
					select	@DirectoryAttempt = 0;
					while not exists (select * from sys.dm_os_file_exists(@BackupPath) where file_is_a_directory = 1)
					begin
						select	@DirectoryAttempt += 1;
						begin try
							-- A Unicode literal lets the extended procedure use the path's inferred string type.
							select	@DirectorySql = N'exec master.sys.xp_create_subdir N''' + replace(@BackupPath, N'''', N'''''') + N''';';
							exec(@DirectorySql);
						end try
						begin catch
							if @DirectoryAttempt >= 3 and not exists (select * from sys.dm_os_file_exists(@BackupPath) where file_is_a_directory = 1)
								throw;
						end catch;
						if exists (select * from sys.dm_os_file_exists(@BackupPath) where file_is_a_directory = 1)
							break;
						if @DirectoryAttempt >= 3
							throw 50000, 'Backup directory creation failed.', 1;
						-- Concurrent creators may race on shared ancestors; retry the remaining path.
						waitfor delay '00:00:01';
					end
				end

				select	@SQL = iif(@EffectiveBackupType in ('FULL', 'DIFF'), 'backup database ', 'backup log ')
							+ quotename(@DatabaseName) + ' to ' + @BackupDevice + ' = N''' + replace(@BackupFileName, N'''', N'''''') + ''' with ',
						@EffectiveOptions = iif(@BackupCompression = 1, N'compression', N'no_compression');

				if @EffectiveBackupType = 'DIFF'
					select	@EffectiveOptions += @OptionSeparator + N'differential';
				if @CopyOnly = 1 or @IsReadOnly = 1
					select	@EffectiveOptions += @OptionSeparator + N'copy_only';
				select	@EffectiveOptions += coalesce(@OptionSeparator + @OtherBackupOptions, N'');
				select	@SQL += @EffectiveOptions;

				exec(@SQL);

				select	@StepEndTime = sysutcdatetime();
				insert into z.BackupRestoreHistory (BatchID, Operation, DatabaseName, BackupType, IsCopyOnly, BackupFile, StartTime, EndTime, DurationMs, Status)
					values (@RunBatchID, 'Backup', @DatabaseName, @EffectiveBackupType, @StepIsCopyOnly, left(@BackupFileName, 1024), @StepStartTime, @StepEndTime, datediff_big(millisecond, @StepStartTime, @StepEndTime), 'Succeeded');

				if @NeedsFull = 1 and @EffectiveBackupType = 'FULL'
				begin
					select	@BackupFileName = null, @StepStartTime = sysutcdatetime(), @EffectiveBackupType = @BackupType,
							@StepIsCopyOnly = iif(@BackupType = 'DIFF', 0, iif(@CopyOnly = 1 or @IsReadOnly = 1, 1, 0)),
							@DifferentialBaseLSN = null, @DifferentialBaseGUID = null;
					exec @Proc @ReadBaseSql, @ReadBaseParameters, @BaseLSN = @DifferentialBaseLSN output, @BaseGUID = @DifferentialBaseGUID output;
					if @DifferentialBaseLSN is null or @DifferentialBaseGUID is null or @DifferentialBaseGUID = @PreviousBaseGUID
						throw 50000, 'The fallback full backup did not establish a new differential base. Do not use COPY_ONLY for FullBackupIfNeeded.', 1;
					if @BackupType = 'LOG'
					begin
						select	@LastLogBackupLSN = null;
						select	@LastLogBackupLSN = last_log_backup_lsn
						from sys.database_recovery_status
						where database_id = db_id(@DatabaseName);
						if @LastLogBackupLSN is null
							throw 50000, 'The fallback full backup did not initialize log backups.', 1;
					end
					select	@EffectiveBackupType = iif(@BackupType = 'LOG', 'LOG', null), @NeedsFull = 0;
				end
				else
				begin
					select	@EffectiveBackupType = null;
				end
			end

			if @IsUrl = 0 and @RetentionHours is not null and len(@DatabaseBackupFolder) <= 4000
			begin
				begin try
					exec z.usp_CleanupDatabaseBackups
						@BackupFolder = @DatabaseBackupFolder,
						@RetentionHours = @RetentionHours,
						@BackupType = @BackupType,
						@KeepLatestChain = 1,
						@UseBackupHeader = 0;
				end try
				begin catch
				end catch;
			end
		end try
		begin catch
			select	@StepEndTime = sysutcdatetime(), @ErrorNumber = error_number(), @ErrorMessage = left(error_message(), 512),
					@FailedCount += 1, @FirstErrorMessage = isnull(@FirstErrorMessage, @DatabaseName + N': ' + left(error_message(), 440));
			insert into z.BackupRestoreHistory (BatchID, Operation, DatabaseName, BackupType, IsCopyOnly, BackupFile, StartTime, EndTime, DurationMs, Status, ErrorNumber, ErrorMessage)
				values (@RunBatchID, 'Backup', @DatabaseName, @EffectiveBackupType, @StepIsCopyOnly, left(@BackupFileName, 1024), @StepStartTime, @StepEndTime, datediff_big(millisecond, @StepStartTime, @StepEndTime), 'Failed', @ErrorNumber, @ErrorMessage);
			print N'Backup failed for ' + quotename(@DatabaseName) + N': ' + isnull(@ErrorMessage, N'');
		end catch;

		fetch next from cCommands into @DatabaseName, @StandardizedDatabaseName, @IsReadOnly;
	end
	close cCommands;
	deallocate cCommands;

	if @FailedCount > 0
	begin
		select	@ErrorMessage = iif(
					@FailedCount = 1,
					N'Backup failed for 1 database (' + @FirstErrorMessage + N').',
					concat(N'Backup failed for ', @FailedCount, N' databases. First failure: ', @FirstErrorMessage)
				);
		throw 50000, @ErrorMessage, 1;
	end
end
go
