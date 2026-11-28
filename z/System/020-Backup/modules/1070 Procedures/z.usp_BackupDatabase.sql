/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/020-Backup/modules/1070%20Procedures/z.usp_BackupDatabase.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/020-Backup/docs/reference/z.usp_BackupDatabase.md

Backs up selected databases sequentially or in parallel via SQL Server Agent to filesystem or supported URL destinations.
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
	@RetentionHours int = null,
	@Threads int = 1
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
			@RunBatchID uniqueidentifier = isnull(try_convert(uniqueidentifier, session_context(N'z.BackupDatabase.BatchID')), newid()),
			@FailedCount int = 0, @FirstErrorMessage nvarchar(512), @DatabaseCount int = 0,
			@StepStartTime datetime2(3), @StepEndTime datetime2(3), @StepIsCopyOnly bit, @ErrorNumber int, @ErrorMessage nvarchar(512);

	-- The primary file identifies the database base; newly added secondary files may have none.
	declare	@ReadBaseSql nvarchar(max) = N'select @BaseLSN = differential_base_lsn, @BaseGUID = differential_base_guid from sys.database_files where file_id = 1 and type = 0;',
			@ReadBaseParameters nvarchar(100) = N'@BaseLSN numeric(25,0) output, @BaseGUID uniqueidentifier output';

	select	@BackupType = upper(trim(@BackupType)),
			@ServerName = nullif(trim(isnull(nullif(trim(@ServerName), N''), @@servername)), N''),
			@CreateServerInstanceFolder = isnull(@CreateServerInstanceFolder, 1),
			@CreateBackupTypeFolder = isnull(@CreateBackupTypeFolder, 1),
			@Threads = isnull(@Threads, 1);

	if @BackupType is null or @BackupType not in ('FULL', 'LOG', 'DIFF')
		throw 50000, '@BackupType must be Full, Log, or Diff', 1;

	if @RetentionHours <= 0
		throw 50000, '@RetentionHours must be positive or NULL.', 1;

	if @Threads <= 0
		throw 50000, '@Threads must be positive.', 1;

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

	select	@DatabaseCount = @@rowcount;
	if @DatabaseCount = 0
	begin
		print 'No databases to be backup.';
		return;
	end;

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

	if @Threads = 1 or @DatabaseCount = 1
	begin
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
	end
	else
	begin
		if z.fn_IsSQLAgentRunning() <> 1
			throw 50000, 'SQL Server Agent is not running or is not visible to this caller.', 1;

		declare	@EffectiveThreads int = iif(@Threads < @DatabaseCount, @Threads, @DatabaseCount),
				@RunIDHex varchar(32) = lower(replace(convert(varchar(36), @RunBatchID), '-', '')),
				@MinHistoryID bigint = datediff_big(second, '19000101', dateadd(second, -10, getutcdate())) * 268435456,
				@ExecutorName nvarchar(128), @WorkerPrefix nvarchar(128), @WorkerName nvarchar(128),
				@JobNamePrefix nvarchar(128), @JobServiceName nvarchar(255), @Command nvarchar(max),
				@OriginalContextInfo varbinary(128), @ParentContextInfo varbinary(128), @ParentContextHexLiteral nvarchar(260),
				@HasContextInfo bit = 0, @BackupArguments nvarchar(max), @ExecutorDDL nvarchar(max), @WorkerDDL nvarchar(max),
				@CleanupSql nvarchar(max), @LeftoverWorkerCount int = 0, @AnyWorkerStarted bit = 0,
				@DatabaseID int, @CreateDate datetime, @WorkerOrdinal int = 0,
				@DatabaseLiteral nvarchar(max), @DatabaseSelectorLiteral nvarchar(max), @IdentityPredicate nvarchar(max),
				@BackupTypeLiteral nvarchar(60) = N'''' + replace(@BackupType, N'''', N'''''') + N'''',
				@BatchIDLiteral nvarchar(40) = N'''' + convert(nvarchar(36), @RunBatchID) + N'''',
				@IsCopyOnlyLiteral nvarchar(1), @ThreadNumber int = 1, @JobID uniqueidentifier,
				@Started bit, @StartAttempts tinyint, @NextStartAttemptAtUTC datetime2(7), @RemoveReturnCode int,
				@IdleChecks int = 0, @StuckJobCount int = 0;

		declare @Jobs table
		(
			ThreadNumber int primary key,
			JobID uniqueidentifier not null,
			ServiceName nvarchar(255) not null,
			StartAttempts tinyint not null default (0),
			NextStartAttemptAtUTC datetime2(7) not null,
			Started bit not null default (0)
		);

		select	@ExecutorName = N'usp_BackupDatabaseExecutor_' + convert(nvarchar(32), @RunIDHex),
				@WorkerPrefix = N'usp_BackupDatabaseWorker_' + convert(nvarchar(32), @RunIDHex) + N'_',
				@JobNamePrefix = N'BackupDatabase_' + convert(nvarchar(32), @RunIDHex) + N'_',
				@ParentContextInfo = convert(varbinary(128), 'z.BackupDatabase:' + @RunIDHex);
		select	@ParentContextHexLiteral = convert(nvarchar(260), @ParentContextInfo, 1);

		if len(N'z_' + quotename(db_name(), '(') + N'_' + @JobNamePrefix + convert(nvarchar(10), @EffectiveThreads)) > 128
			throw 50000, 'The current database name is too long for unique backup worker job names.', 1;

		select	@BackupArguments = convert(nvarchar(max), N', @BackupType = N''') + replace(@BackupType, N'''', N'''''') + N''''
				+ N', @BackupFolder = N''' + replace(convert(nvarchar(max), @BackupFolder), N'''', N'''''') + N''''
				+ N', @BackupCompression = ' + convert(nvarchar(4), @BackupCompression)
				+ N', @OtherBackupOptions = ' + isnull(N'N''' + replace(@OtherBackupOptions, N'''', N'''''') + N'''', N'null')
				+ N', @ServerName = N''' + replace(@ServerName, N'''', N'''''') + N''''
				+ N', @BackupFileNameFormat = N''' + replace(convert(nvarchar(max), @BackupFileNameFormat), N'''', N'''''') + N''''
				+ N', @FullBackupIfNeeded = ' + isnull(convert(nvarchar(4), @FullBackupIfNeeded), N'null')
				+ N', @CopyOnly = ' + isnull(convert(nvarchar(4), @CopyOnly), N'null')
				+ N', @CreateServerInstanceFolder = ' + convert(nvarchar(4), @CreateServerInstanceFolder)
				+ N', @CreateBackupTypeFolder = ' + convert(nvarchar(4), @CreateBackupTypeFolder)
				+ N', @RetentionHours = ' + isnull(convert(nvarchar(11), @RetentionHours), N'null')
				+ N', @Threads = 1;';

		select	@OriginalContextInfo = isnull(context_info(), 0x);
		set context_info @ParentContextInfo;
		select	@HasContextInfo = 1;

		begin try
			select	@ExecutorDDL = N'create procedure [z].' + quotename(@ExecutorName) + N'
as
begin
	set nocount, xact_abort on;
	exec z.usp_ExecuteProcedures
		@SchemaNames = N''z'',
		@ProcedureNames = N''usp!_BackupDatabaseWorker!_' + convert(nvarchar(32), @RunIDHex) + N'!_%'';
end;';
			exec(@ExecutorDDL);

			declare cWorkers cursor local fast_forward for
				select	d.database_id, l.DatabaseName, d.create_date, l.IsReadOnly
				from @DatabaseList l
					inner join sys.databases d on d.name collate database_default = l.DatabaseName
				order by l.DataSizeMB desc, l.DatabaseName asc;
			open cWorkers;
			fetch next from cWorkers into @DatabaseID, @DatabaseName, @CreateDate, @IsReadOnly;
			while @@fetch_status = 0
			begin
				select	@WorkerOrdinal += 1;
				select	@WorkerName = @WorkerPrefix + right(N'00000' + convert(nvarchar(10), @WorkerOrdinal), 5),
						@DatabaseLiteral = N'N''' + replace(@DatabaseName, N'''', N'''''') + N'''',
						@DatabaseSelectorLiteral = N'N''["' + replace(string_escape(@DatabaseName, 'json'), N'''', N'''''') + N'"]''',
						@IsCopyOnlyLiteral = iif(@BackupType = 'DIFF', N'0', iif(@CopyOnly = 1 or @IsReadOnly = 1, N'1', N'0'));
				select	@IdentityPredicate = convert(nvarchar(max), N'database_id = ') + convert(nvarchar(11), @DatabaseID)
						+ N' and name = ' + @DatabaseLiteral + N' and create_date = convert(datetime, N'''
						+ convert(nvarchar(23), @CreateDate, 121) + N''', 121) and state = 0';
				select	@WorkerDDL = N'create procedure [z].' + quotename(@WorkerName) + N'
as
begin
	set nocount, xact_abort on;
	if exists (
		select	1
		from sys.dm_exec_requests r
		where r.context_info = ' + @ParentContextHexLiteral + N'
	)
	begin
		declare	@StepStartTime datetime2(3) = sysutcdatetime(), @StepEndTime datetime2(3),
				@ErrorNumber int, @ErrorMessage nvarchar(512);
		begin try
			exec sys.sp_set_session_context @key = N''z.BackupDatabase.BatchID'', @value = ' + @BatchIDLiteral + N';
			if not exists (select 1 from sys.databases where ' + @IdentityPredicate + N')
				throw 50000, ''The selected database is no longer the same online database.'', 1;
			exec z.usp_BackupDatabase @Databases = ' + @DatabaseSelectorLiteral + @BackupArguments + N'
		end try
		begin catch
			if @@trancount > 0
				rollback;
			select	@StepEndTime = sysutcdatetime(), @ErrorNumber = error_number(), @ErrorMessage = left(error_message(), 512);
			begin try
				if not exists (
					select	1
					from z.BackupRestoreHistory
					where HistoryID >= ' + convert(nvarchar(21), @MinHistoryID) + N'
						and BatchID = ' + @BatchIDLiteral + N'
						and DatabaseName = ' + @DatabaseLiteral + N'
						and Status = ''Failed''
				)
					insert into z.BackupRestoreHistory (BatchID, Operation, DatabaseName, BackupType, IsCopyOnly, StartTime, EndTime, DurationMs, Status, ErrorNumber, ErrorMessage)
						values (' + @BatchIDLiteral + N', ''Backup'', ' + @DatabaseLiteral + N', ' + @BackupTypeLiteral + N', ' + @IsCopyOnlyLiteral + N', @StepStartTime, @StepEndTime, datediff_big(millisecond, @StepStartTime, @StepEndTime), ''Failed'', @ErrorNumber, @ErrorMessage);
			end try
			begin catch
			end catch;
		end catch;
		begin try
			exec sys.sp_set_session_context @key = N''z.BackupDatabase.BatchID'', @value = null;
		end try
		begin catch
		end catch;
	end;
	drop procedure if exists [z].' + quotename(@WorkerName) + N';
end;';
				exec(@WorkerDDL);
				fetch next from cWorkers into @DatabaseID, @DatabaseName, @CreateDate, @IsReadOnly;
			end;
			close cWorkers;
			deallocate cWorkers;

			select	@Command = N'exec [z].' + quotename(@ExecutorName) + N';';
			while @ThreadNumber <= @EffectiveThreads
			begin
				select	@JobServiceName = @JobNamePrefix + convert(nvarchar(10), @ThreadNumber),
						@JobID = null;
				exec z.usp_CreateServiceJob
					@Name = @JobServiceName,
					@Command = @Command,
					@Description = N'Temporary multi-threaded backup worker job.',
					@DeleteAfterExecution = 3,
					@CreateSchedule = 0,
					@JobID = @JobID output;
				insert into @Jobs (ThreadNumber, JobID, ServiceName, StartAttempts, NextStartAttemptAtUTC)
					values (@ThreadNumber, @JobID, @JobServiceName, 0, sysutcdatetime());
				select	@ThreadNumber += 1;
			end;

			waitfor delay '00:00:00.005';

			select	@ThreadNumber = 0;
			while exists (select 1 from @Jobs)
			begin
				select	top (1)
						@ThreadNumber = ThreadNumber,
						@JobID = JobID,
						@JobServiceName = ServiceName,
						@Started = Started,
						@StartAttempts = StartAttempts,
						@NextStartAttemptAtUTC = NextStartAttemptAtUTC
				from @Jobs
				where ThreadNumber > @ThreadNumber
				order by ThreadNumber;
				if @@rowcount = 0
				begin
					if exists (select 1 from @Jobs)
						and not exists (select 1 from @Jobs where Started = 0)
						and not exists (select 1 from @Jobs where z.fn_IsSQLJobRunning(JobID) = 1)
					begin
						select	@IdleChecks += 1;
						if @IdleChecks >= 5
						begin
							select	@StuckJobCount = count(*)
							from @Jobs;

							declare cStuckJobs cursor local static read_only for
							select	JobID
							from @Jobs;
							open cStuckJobs;
							while 1 = 1
							begin
								fetch next from cStuckJobs into @JobID;
								if @@fetch_status <> 0
									break;
								begin try
									exec msdb.dbo.sp_delete_job @job_id = @JobID, @delete_unused_schedule = 1, @delete_history = 1;
								end try
								begin catch
								end catch;
							end;
							close cStuckJobs;
							deallocate cStuckJobs;

							delete @Jobs;
							break;
						end;
					end;
					else
						select	@IdleChecks = 0;

					select	@ThreadNumber = 0;
					waitfor delay '00:00:01';
					continue;
				end;
				if not exists (select 1 from msdb.dbo.sysjobs where job_id = @JobID)
				begin
					select	@AnyWorkerStarted = 1;
					delete @Jobs where ThreadNumber = @ThreadNumber;
					continue;
				end;
				if @Started = 1
					continue;
				if z.fn_IsSQLJobRunning(@JobID) = 1
				begin
					update @Jobs
						set Started = 1, @AnyWorkerStarted = 1
					where ThreadNumber = @ThreadNumber;
					continue;
				end;
				if @NextStartAttemptAtUTC > sysutcdatetime()
					continue;
				begin try
					if @StartAttempts < 3
					begin
						select	@StartAttempts += 1;
						exec msdb.dbo.sp_start_job @job_id = @JobID;
					end
					else
					begin
						exec @RemoveReturnCode = msdb.dbo.sp_delete_job @job_id = @JobID,
							@delete_unused_schedule = 1, @delete_history = 1;
						if @RemoveReturnCode = 0 or not exists (select 1 from msdb.dbo.sysjobs where job_id = @JobID)
							delete @Jobs where ThreadNumber = @ThreadNumber;
						continue;
					end;
				end try
				begin catch
					if @@trancount > 0
						rollback;
					if not exists (select 1 from msdb.dbo.sysjobs where job_id = @JobID)
					begin
						select	@AnyWorkerStarted = 1;
						delete @Jobs where ThreadNumber = @ThreadNumber;
						continue;
					end;
				end catch;
				update @Jobs
					set StartAttempts = @StartAttempts,
						NextStartAttemptAtUTC = dateadd(second, 10, sysutcdatetime())
				where ThreadNumber = @ThreadNumber;
			end;
		end try
		begin catch
			if @@trancount > 0
				rollback;
			if @HasContextInfo = 1
			begin
				set context_info @OriginalContextInfo;
				select	@HasContextInfo = 0;
			end;
			begin try
				if not exists (select 1 from @Jobs where z.fn_IsSQLJobRunning(JobID) = 1)
				begin
					declare cCleanupJobs cursor local static read_only for
						select	JobID
						from @Jobs;
					open cCleanupJobs;
					fetch next from cCleanupJobs into @JobID;
					while @@fetch_status = 0
					begin
						begin try
							if exists (select 1 from msdb.dbo.sysjobs where job_id = @JobID) and z.fn_IsSQLJobRunning(@JobID) = 0
								exec msdb.dbo.sp_delete_job @job_id = @JobID, @delete_unused_schedule = 1, @delete_history = 1;
						end try
						begin catch
						end catch;
						fetch next from cCleanupJobs into @JobID;
					end;
					close cCleanupJobs;
					deallocate cCleanupJobs;

					select	@CleanupSql = string_agg(convert(nvarchar(max), N'drop procedure if exists [z].' + quotename(p.name) + N';'), N' ')
					from sys.procedures p
					where p.schema_id = schema_id('z')
						and (
							left(p.name, len(@WorkerPrefix)) = @WorkerPrefix collate database_default
							or p.name = @ExecutorName collate database_default
						);
					if @CleanupSql is not null
						exec(@CleanupSql);
				end;
			end try
			begin catch
			end catch;
			throw;
		end catch;

		if @HasContextInfo = 1
		begin
			set context_info @OriginalContextInfo;
			select	@HasContextInfo = 0;
		end;

		select	@LeftoverWorkerCount = count(*),
				@CleanupSql = string_agg(convert(nvarchar(max), N'drop procedure if exists [z].' + quotename(p.name) + N';'), N' ')
		from sys.procedures p
		where p.schema_id = schema_id('z')
			and left(p.name, len(@WorkerPrefix)) = @WorkerPrefix collate database_default;

		select	@CleanupSql = concat(
					@CleanupSql,
					iif(@CleanupSql is null, N'', N' '),
					N'drop procedure if exists [z].', quotename(@ExecutorName), N';'
				);
		exec(@CleanupSql);

		if @AnyWorkerStarted = 0
			throw 50000, 'No SQL Server Agent worker jobs started for multi-threaded backup.', 1;

		if @StuckJobCount > 0
		begin
			select	@ErrorMessage = concat(
						N'Multi-threaded backup stopped waiting for ', @StuckJobCount,
						N' SQL Server Agent worker job(s) that were no longer running but were not removed; ',
						@LeftoverWorkerCount, N' backup worker procedure(s) did not complete.'
					);
			throw 50000, @ErrorMessage, 1;
		end;

		;with FailedDatabases as
		(
			select	DatabaseName,
					isnull(ErrorMessage, N'Backup failed.') ErrorMessage,
					row_number() over (order by HistoryID asc) RowNum
			from z.BackupRestoreHistory
			where HistoryID >= @MinHistoryID
				and BatchID = @RunBatchID
				and Status = 'Failed'
		)
		select	@FailedCount = count(distinct DatabaseName),
				@FirstErrorMessage = max(case when RowNum = 1 then DatabaseName + N': ' + left(ErrorMessage, 440) end)
		from FailedDatabases;

		if @FailedCount = 0 and @LeftoverWorkerCount > 0
			select	@FailedCount = @LeftoverWorkerCount,
					@FirstErrorMessage = N'One or more backup worker procedures did not complete.';
	end;

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
