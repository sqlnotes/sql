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
	@Databases nvarchar(max) = 'AllDatabases', --Group keyword, comma-separated names or JSON array.
	@BackupType nvarchar(50) = 'Full', --'Full, Log, Diff'
	@BackupFolder nvarchar(4000) = null, --Filesystem folder or Azure/S3 URL prefix.
	@BackupCompression bit = 1,
	@OtherBackupOptions nvarchar(max) = null,-- 'stats = 1',
	@ServerName sysname = null, --Backup path label; NULL uses @@servername.
	@BackupFileNameFormat nvarchar(4000) = N'{ServerName}${InstanceName}${DatabaseName}_{yyyyMMdd}_{HHmmssfffffff}',
	@FullBackupIfNeeded bit = 1,
	@CopyOnly bit = 0
)
as
begin
	set nocount, xact_abort on;

	if @@trancount > 0 or @@options & 2 = 2
		throw 50000, 'Backup cannot run inside a transaction or implicit transactions.', 1;

	declare	@BackupPath nvarchar(max), @SQL nvarchar(max), @DatabaseName nvarchar(128), @StandardizedDatabaseName nvarchar(128), @FolderSeparator varchar(1),
			@BackupFileName nvarchar(max), @Platform nvarchar(256), @DirectorySql nvarchar(max), @DirectoryAttempt int,
			@IsUrl bit, @BackupDevice varchar(4), @BackupExtension varchar(5), @IsReadOnly bit,
			@EffectiveBackupType nvarchar(50), @NeedsFull bit, @ExecSqlProcedure nvarchar(276), @DifferentialBaseLSN numeric(25,0),
			@DifferentialBaseGUID uniqueidentifier, @PreviousBaseGUID uniqueidentifier, @LastLogBackupLSN numeric(25,0),
			@EffectiveOptions nvarchar(max), @OptionSeparator nvarchar(4) = nchar(13) + nchar(10) + N', ',
			@ServerLabel nvarchar(128), @InstanceLabel nvarchar(128), @InstanceSeparator int, @BackupTime datetime2(7),
			@FormattedName nvarchar(max), @FormatOffset int, @TokenStart int, @TokenEnd int, @TokenValue nvarchar(128);
	-- The primary file identifies the database base; newly added secondary files may have none.
	declare	@ReadBaseSql nvarchar(max) = N'select	
@BaseLSN = differential_base_lsn, @BaseGUID = differential_base_guid
from sys.database_files 
where file_id = 1 
	and type = 0;
',
			@ReadBaseParameters nvarchar(100) = N'@BaseLSN numeric(25,0) output, @BaseGUID uniqueidentifier output';

	select	@BackupType = upper(trim(@BackupType)), @ServerName = nullif(trim(isnull(nullif(trim(@ServerName), N''), @@servername)), '');

	if @BackupType is null or @BackupType not in ('FULL', 'LOG', 'DIFF')
		throw 50000, '@BackupType must be Full, Log, or Diff', 1;

	if @ServerName is null
		throw 50000, 'ServerName must identify a server and an optional nonempty instance name.', 1;

	if nullif(trim(@BackupFileNameFormat), N'') is null
		select	@BackupFileNameFormat = N'{ServerName}${InstanceName}${DatabaseName}_{yyyyMMdd}_{HHmmssfffffff}';

	select	@InstanceSeparator = charindex(N'\', @ServerName);
	select	@ServerLabel = z.fn_StandardizeFileName(iif(@InstanceSeparator = 0, @ServerName, left(@ServerName, case when @InstanceSeparator > 0 then @InstanceSeparator - 1 else 0 end))),
			@InstanceLabel = z.fn_StandardizeFileName(iif(@InstanceSeparator = 0, N'MSSQLSERVER', substring(@ServerName, @InstanceSeparator + 1, 128)));

	if nullif(trim(translate(@OtherBackupOptions, nchar(9) + nchar(10) + nchar(11) + nchar(12) + nchar(13), N'     ')), N'') is null
		select	@OtherBackupOptions = null;

	if @BackupCompression is null
	begin
		select	@BackupCompression = isnull((select cast(value as int) from sys.configurations where name = 'backup compression default'), 0)
	end

	declare @DatabasesJson nvarchar(max), @DatabasesCsv nvarchar(max);
	if isjson(@Databases) = 1 and left(ltrim(translate(@Databases, nchar(9) + nchar(10) + nchar(13), N'   ')), 1) = N'['
		select	@DatabasesJson = @Databases;
	else if @Databases not in (N'AllDatabases', N'UserDatabases', N'SystemDatabases')
		select	@DatabasesCsv = @Databases;

	declare @DatabaseList table(DatabaseName nvarchar(128) primary key, StandardizedDatabaseName nvarchar(128) not null, DataSizeMB bigint, IsReadOnly bit)

	insert into @DatabaseList(DatabaseName, StandardizedDatabaseName, DataSizeMB, IsReadOnly)
		select	d.name, z.fn_StandardizeFileName(d.name), sum(cast(m.size as bigint)) * 8/1024, d.is_read_only
		from sys.databases d
			inner join sys.master_files m on m.database_id = d.database_id
		where d.state_desc not in ('RESTORING', 'RECOVERING', 'RECOVERY_PENDING', 'SUSPECT', 'EMERGENCY')
			and d.name not in ('tempdb')
			and m.type_desc in ('ROWS')
			and (
					@Databases = N'AllDatabases'
					or @Databases = N'UserDatabases' and d.name not in (N'master', N'model', N'msdb')
					or @Databases = N'SystemDatabases' and d.name in (N'master', N'model', N'msdb')
					or exists (select 1 from string_split(@DatabasesCsv, N',') s where trim(s.value) = d.name)
					or exists (
						select 1 from openjson(@DatabasesJson) j
						where j.type = 1 and j.value = d.name and datalength(j.value) = datalength(d.name)
					)
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
		select	@BackupFolder = nullif(trim(cast(serverproperty('InstanceDefaultBackupPath') as nvarchar(4000))), '')
	end
	select	@BackupFolder = nullif(trim(@BackupFolder), '')
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
		if @Platform = N'Windows' select @BackupFolder = replace(@BackupFolder, N'/', N'\');
	end
	while right(@BackupFolder, 1) = @FolderSeparator and len(@BackupFolder) > 1
		select	@BackupFolder = left(@BackupFolder, len(@BackupFolder) -1)


	begin try
		declare cCommands cursor local static for
			select	DatabaseName, StandardizedDatabaseName, IsReadOnly
			from @DatabaseList order by DataSizeMB asc;
		open cCommands;
		fetch next from cCommands into @DatabaseName, @StandardizedDatabaseName, @IsReadOnly;
		while @@fetch_status = 0
		begin
			select	@EffectiveBackupType = @BackupType, @NeedsFull = 0;
			if @FullBackupIfNeeded = 1 and @BackupType in ('DIFF', 'LOG')
			begin
				select	@ExecSqlProcedure = quotename(@DatabaseName) + N'.sys.sp_executesql', 
						@DifferentialBaseLSN = null, @DifferentialBaseGUID = null, @LastLogBackupLSN = null;
				exec @ExecSqlProcedure @ReadBaseSql, @ReadBaseParameters, @BaseLSN = @DifferentialBaseLSN output, @BaseGUID = @DifferentialBaseGUID output;
				if @BackupType = 'LOG'
				begin
					select	@LastLogBackupLSN = last_log_backup_lsn 
					from sys.database_recovery_status 
					where database_id = db_id(@DatabaseName);
				end
				if @BackupType = 'DIFF' and (@DifferentialBaseLSN is null or @DifferentialBaseGUID is null)
					or @BackupType = 'LOG' and @LastLogBackupLSN is null
					select	@NeedsFull = 1, @EffectiveBackupType = 'FULL';
				if @NeedsFull = 1 and @IsReadOnly = 1
					throw 50000, 'FullBackupIfNeeded cannot establish a regular full backup under the read-only COPY_ONLY policy.', 1;
				if @NeedsFull = 1 and @CopyOnly = 1
					throw 50000, 'FullBackupIfNeeded requires a regular full backup. Set CopyOnly to 0 to establish the backup base.', 1;
				select	@PreviousBaseGUID = @DifferentialBaseGUID;
			end
			while @EffectiveBackupType is not null
			begin
				select	@BackupPath = convert(nvarchar(max), @BackupFolder)
						+ iif(right(@BackupFolder, 1) = @FolderSeparator, N'', @FolderSeparator)
						+ @ServerLabel + @FolderSeparator + @InstanceLabel
						+ @FolderSeparator + @StandardizedDatabaseName + @FolderSeparator + @EffectiveBackupType + @FolderSeparator,
						@BackupTime = sysutcdatetime(), @FormattedName = N'', @FormatOffset = 1;
				while 1 = 1
				begin
					select	@TokenStart = charindex(N'{', @BackupFileNameFormat, @FormatOffset);
					select	@TokenEnd = charindex(N'}', @BackupFileNameFormat, @TokenStart + 1);
					if @TokenStart = 0 or @TokenEnd = 0
					begin
						select	@FormattedName += substring(@BackupFileNameFormat, @FormatOffset, 4000);
						break;
					end
					select	@TokenValue = case substring(@BackupFileNameFormat, @TokenStart, @TokenEnd - @TokenStart + 1)
							when N'{ServerName}' then @ServerLabel 
							when N'{InstanceName}' then @InstanceLabel 
							when N'{DatabaseName}' then @StandardizedDatabaseName 
							when N'{BackupType}' then @EffectiveBackupType
							when N'{yyyyMMdd}' then convert(nvarchar(8), @BackupTime, 112)
							when N'{HHmmssfffffff}' then format(@BackupTime, 'HHmmssfffffff', 'en-US')
							when N'{HHmmssffffff}' then format(@BackupTime, 'HHmmssffffff', 'en-US')
							when N'{HHmmss}' then format(@BackupTime, 'HHmmss', 'en-US')
							when N'{fffffff}' then format(@BackupTime, 'fffffff', 'en-US')
							when N'{ffffff}' then format(@BackupTime, 'ffffff', 'en-US') end;
					-- Keep scanning the template after a literal opening brace.
					select	@FormattedName += substring(@BackupFileNameFormat, @FormatOffset, @TokenStart - @FormatOffset)
								+ isnull(@TokenValue, substring(@BackupFileNameFormat, @TokenStart, 1)),
							@FormatOffset = iif(@TokenValue is null, @TokenStart, @TokenEnd) + 1;
				end
				select	@BackupExtension =	case @EffectiveBackupType 
												when 'FULL' then '.bak' 
												when 'DIFF' then '.diff' 
												else '.trn' 
											end;
				select	@BackupFileName = @BackupPath + z.fn_StandardizeFileName(@FormattedName) + @BackupExtension;
				if @IsUrl = 0
				begin
					select	@DirectoryAttempt = 0;
					while not exists(select * from sys.dm_os_file_exists(@BackupPath) where file_is_a_directory = 1)
					begin
						select	@DirectoryAttempt += 1;
						begin try
							-- A Unicode literal lets the extended procedure use the path's inferred string type.
							select	@DirectorySql = N'exec master.sys.xp_create_subdir N''' + replace(@BackupPath, N'''', N'''''') + N''';';
							exec(@DirectorySql);
						end try
						begin catch
							if @DirectoryAttempt >= 3 and not exists(select * from sys.dm_os_file_exists(@BackupPath) where file_is_a_directory = 1) 
								throw;
						end catch;
						if exists(select * from sys.dm_os_file_exists(@BackupPath) where file_is_a_directory = 1) 
							break;
						if @DirectoryAttempt >= 3 throw 50000, 'Backup directory creation failed.', 1;
						-- Concurrent creators may race on shared ancestors; retry the remaining path.
						waitfor delay '00:00:00.100';
					end
				end
				if @EffectiveBackupType in ('FULL', 'DIFF')
					select	@SQL = 'backup database ' + quotename(@DatabaseName) + ' to ' + @BackupDevice + ' = N''' + replace(@BackupFileName, N'''', N'''''') + ''' with ';
				else
					select	@SQL = 'backup log ' + quotename(@DatabaseName) + ' to ' + @BackupDevice + ' = N''' + replace(@BackupFileName, N'''', N'''''') + ''' with ';
				select	@EffectiveOptions = iif(@BackupCompression = 1, N'compression', N'no_compression');
				if @EffectiveBackupType = 'DIFF'
					select	@EffectiveOptions += @OptionSeparator + N'differential';
				if @CopyOnly = 1 or @IsReadOnly = 1
					select	@EffectiveOptions += @OptionSeparator + N'copy_only';
				select	@EffectiveOptions += coalesce(@OptionSeparator + @OtherBackupOptions, N'');
				select	@SQL += @EffectiveOptions;
				print @SQL;
				exec(@SQL);
				if @NeedsFull = 1 and @EffectiveBackupType = 'FULL'
				begin
					select	@DifferentialBaseLSN = null, @DifferentialBaseGUID = null;
					exec @ExecSqlProcedure @ReadBaseSql, @ReadBaseParameters,
						@BaseLSN = @DifferentialBaseLSN output, @BaseGUID = @DifferentialBaseGUID output;
					if @DifferentialBaseLSN is null or @DifferentialBaseGUID is null or @DifferentialBaseGUID = @PreviousBaseGUID
						throw 50000, 'The fallback full backup did not establish a new differential base. Do not use COPY_ONLY for FullBackupIfNeeded.', 1;
					if @BackupType = 'LOG'
					begin
						select	@LastLogBackupLSN = null;
						select	@LastLogBackupLSN = last_log_backup_lsn from sys.database_recovery_status where database_id = db_id(@DatabaseName);
						if @LastLogBackupLSN is null
							throw 50000, 'The fallback full backup did not initialize log backups.', 1;
					end
					select	@EffectiveBackupType = iif(@BackupType = 'LOG', 'LOG', null), @NeedsFull = 0;
				end
				else
					select	@EffectiveBackupType = null;
			end
			fetch next from cCommands into @DatabaseName, @StandardizedDatabaseName, @IsReadOnly;
		end
		close cCommands;
		deallocate cCommands;
	end try
	begin catch
		throw;
	end catch
end
go
