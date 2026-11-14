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
	@Databases nvarchar(max) = 'AllDatabases', --'AllDatabases', 'UserDatabases', 'SystemDatabases', 'Database1,Dabase2...'
	@BackupType nvarchar(50) = 'Full', --'Full, Log, Diff'
	@BackupFolder nvarchar(4000) = null, --Filesystem folder or Azure/S3 URL prefix.
	@BackupCompression bit = 1,
	@OtherBackupOptions nvarchar(max) = null,-- 'stats = 1',
	@ServerName sysname = null, --Backup path label; NULL uses @@servername.
	@BackupFileNameFormat nvarchar(4000) = N'{ServerName}${InstanceName}${DatabaseName}_{yyyyMMdd}_{HHmmssfffffff}',
	@FullBackupIfNeeded bit = 0
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
			@BackupFileName nvarchar(4000), @RawPath nvarchar(max), @Platform nvarchar(256), @DirectoryResult int, @DirectoryAttempt int,
			@IsUrl bit, @BackupDevice varchar(4), @IsReadOnly bit,
			@EffectiveBackupType nvarchar(50), @NeedsFull bit, @DifferentialBaseLSN numeric(25,0),
			@DifferentialBaseGUID uniqueidentifier, @PreviousBaseGUID uniqueidentifier, @LastLogBackupLSN numeric(25,0),
			@EffectiveOptions nvarchar(max), @OptionSeparator nvarchar(4) = nchar(13) + nchar(10) + N', ',
			@ServerLabel nvarchar(128), @InstanceLabel nvarchar(128), @InstanceSeparator int, @BackupTime datetime2(7),
			@EffectiveFileNameFormat nvarchar(max), @FormattedName nvarchar(max), @FormatRemainder nvarchar(max),
			@FormatOffset int, @TokenStart int, @TokenEnd int, @Token nvarchar(128);
	select @BackupType = upper(trim(@BackupType)), @ServerName = coalesce(nullif(trim(@ServerName), N''), @@servername);

	if @BackupType is null or @BackupType not in ('FULL', 'LOG', 'DIFF')
		throw 50000, '@BackupType must be Full, Log, or Diff', 1;
	if nullif(trim(@BackupFileNameFormat), N'') is null
		throw 50000, 'BackupFileNameFormat must specify a filename template without an extension.', 1;
	select @FormatRemainder = @BackupFileNameFormat;
	select @FormatRemainder = replace(replace(replace(replace(@FormatRemainder, N'{ServerName}', N''), N'{InstanceName}', N''), N'{DatabaseName}', N''), N'{BackupType}', N'');
	select @FormatRemainder = replace(replace(replace(replace(replace(replace(@FormatRemainder, N'{yyyyMMdd}', N''), N'{HHmmssfffffff}', N''), N'{HHmmssffffff}', N''), N'{HHmmss}', N''), N'{fffffff}', N''), N'{ffffff}', N'');
	if @FormatRemainder like N'%[{}]%' or @BackupFileNameFormat like N'%[<>:"/\|?*]%'
		throw 50000, 'BackupFileNameFormat contains an unknown token or an invalid filename character.', 1;
	select @InstanceSeparator = charindex(N'\', @ServerName);
	select @ServerLabel = z.fn_StandardizeFileName(iif(@InstanceSeparator = 0, @ServerName, left(@ServerName, case when @InstanceSeparator > 0 then @InstanceSeparator - 1 else 0 end))),
		@InstanceLabel = z.fn_StandardizeFileName(iif(@InstanceSeparator = 0, N'MSSQLSERVER', substring(@ServerName, @InstanceSeparator + 1, 128)));
	if nullif(@ServerLabel, N'') is null or nullif(@InstanceLabel, N'') is null
		throw 50000, 'ServerName must identify a server and an optional nonempty instance name.', 1;
	select @EffectiveFileNameFormat = @BackupFileNameFormat;



	if nullif(trim(translate(@OtherBackupOptions, nchar(9) + nchar(10) + nchar(11) + nchar(12) + nchar(13), N'     ')), N'') is null
		select @OtherBackupOptions = null;

	if @BackupCompression is null
	begin
		select @BackupCompression = isnull((select cast(value as int) from sys.configurations where name = 'backup compression default'), 0)
	end
	declare @DatabaseList table(
								DatabaseName nvarchar(128) primary key,
							StandardizedDatabaseName nvarchar(128) not null, DataSizeMB bigint, IsReadOnly bit
								)

	insert into @DatabaseList(DatabaseName, StandardizedDatabaseName, DataSizeMB, IsReadOnly)
		select	d.name,
				z.fn_StandardizeFileName(d.name),
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
			select @EffectiveBackupType = @BackupType, @NeedsFull = 0;
			if @FullBackupIfNeeded = 1 and @BackupType in ('DIFF', 'LOG')
			begin
				select @DifferentialBaseLSN = null, @DifferentialBaseGUID = null, @LastLogBackupLSN = null;
				-- The primary file identifies the database base; newly added secondary files may have none.
				select @SQL = N'use ' + quotename(@DatabaseName) + N';
select @BaseLSN = differential_base_lsn, @BaseGUID = differential_base_guid
from sys.database_files where file_id = 1 and type = 0;';
				exec sys.sp_executesql @SQL, N'@BaseLSN numeric(25,0) output, @BaseGUID uniqueidentifier output',
					@BaseLSN = @DifferentialBaseLSN output, @BaseGUID = @DifferentialBaseGUID output;
				if @BackupType = 'LOG'
					select @LastLogBackupLSN = last_log_backup_lsn from sys.database_recovery_status where database_id = db_id(@DatabaseName);
				if @BackupType = 'DIFF' and (@DifferentialBaseLSN is null or @DifferentialBaseGUID is null)
					or @BackupType = 'LOG' and @LastLogBackupLSN is null
					select @NeedsFull = 1, @EffectiveBackupType = 'FULL';
				if @NeedsFull = 1 and @IsReadOnly = 1
					throw 50000, 'FullBackupIfNeeded cannot establish a regular full backup under the read-only COPY_ONLY policy.', 1;
				select @PreviousBaseGUID = @DifferentialBaseGUID;
			end
			while @EffectiveBackupType is not null
			begin
				select @RawPath = @BackupFolder + @ServerLabel + @FolderSeparator + @InstanceLabel
					+ @FolderSeparator + @StandardizedDatabaseName + @FolderSeparator + @EffectiveBackupType + @FolderSeparator,
					@BackupTime = sysdatetime(), @FormattedName = N'', @FormatOffset = 1;
				while @FormatOffset <= len(@EffectiveFileNameFormat)
				begin
					select @TokenStart = charindex(N'{', @EffectiveFileNameFormat, @FormatOffset);
					if @TokenStart = 0
					begin
						select @FormattedName += substring(@EffectiveFileNameFormat, @FormatOffset, 4000);
						break;
					end
					select @TokenEnd = charindex(N'}', @EffectiveFileNameFormat, @TokenStart + 1),
						@FormattedName += substring(@EffectiveFileNameFormat, @FormatOffset, @TokenStart - @FormatOffset);
					select @Token = substring(@EffectiveFileNameFormat, @TokenStart + 1, @TokenEnd - @TokenStart - 1);
					select @FormattedName += case @Token
						when N'ServerName' then @ServerLabel when N'InstanceName' then @InstanceLabel when N'DatabaseName' then @StandardizedDatabaseName when N'BackupType' then @EffectiveBackupType
						when N'yyyyMMdd' then convert(nvarchar(8), @BackupTime, 112)
						when N'HHmmssfffffff' then format(@BackupTime, 'HHmmssfffffff', 'en-US')
						when N'HHmmssffffff' then format(@BackupTime, 'HHmmssffffff', 'en-US')
						when N'HHmmss' then format(@BackupTime, 'HHmmss', 'en-US')
						when N'fffffff' then format(@BackupTime, 'fffffff', 'en-US') when N'ffffff' then format(@BackupTime, 'ffffff', 'en-US') end,
						@FormatOffset = @TokenEnd + 1;
				end
				if @FormattedName in (N'', N'.', N'..') or @FormattedName <> z.fn_StandardizeFileName(@FormattedName)
					throw 50000, 'BackupFileNameFormat must render a nonempty filename without invalid characters or trailing periods.', 1;
				select @FormattedName += case @EffectiveBackupType when 'FULL' then N'.bak' when 'DIFF' then N'.diff' else N'.trn' end;
				if len(@FormattedName) > 255 or len(@RawPath + @FormattedName) > iif(@IsUrl = 1, 4000, 260)
					throw 50000, 'The backup filename or destination path is too long; use a shorter filename format or backup folder.', 1;
				select @BackupPath = @RawPath, @BackupFileName = @RawPath + @FormattedName;
				if @IsUrl = 0
				begin
					select @DirectoryAttempt = 0;
					while not exists(select * from sys.dm_os_file_exists(@BackupPath) where file_is_a_directory = 1)
					begin
						select @DirectoryAttempt += 1;
						begin try
							exec @DirectoryResult = master.sys.xp_create_subdir @BackupPath;
						end try
						begin catch
							if @DirectoryAttempt >= 3 and not exists(select * from sys.dm_os_file_exists(@BackupPath) where file_is_a_directory = 1) throw;
						end catch;
						if exists(select * from sys.dm_os_file_exists(@BackupPath) where file_is_a_directory = 1) break;
						if @DirectoryAttempt >= 3 throw 50000, 'Backup directory creation failed.', 1;
						-- Concurrent creators may race on shared ancestors; retry the remaining path.
						waitfor delay '00:00:00.100';
					end
				end
				if @EffectiveBackupType in ('FULL', 'DIFF')
					select @SQL = 'backup database ' + quotename(@DatabaseName) + ' to ' + @BackupDevice + ' = N''' + replace(@BackupFileName, N'''', N'''''') + ''' with ';
				else
					select @SQL = 'backup log ' + quotename(@DatabaseName) + ' to ' + @BackupDevice + ' = N''' + replace(@BackupFileName, N'''', N'''''') + ''' with ';
				select @EffectiveOptions = iif(@BackupCompression = 1, N'compression', N'no_compression');
				if @EffectiveBackupType = 'DIFF'
					select @EffectiveOptions += @OptionSeparator + N'differential';
				if @IsReadOnly = 1
					select @EffectiveOptions += @OptionSeparator + N'copy_only';
				select @EffectiveOptions += coalesce(@OptionSeparator + @OtherBackupOptions, N'');
				select @SQL += @EffectiveOptions;
				print @SQL;
				exec(@SQL);
				if @NeedsFull = 1 and @EffectiveBackupType = 'FULL'
				begin
					select @DifferentialBaseLSN = null, @DifferentialBaseGUID = null;
					select @SQL = N'use ' + quotename(@DatabaseName) + N';
select @BaseLSN = differential_base_lsn, @BaseGUID = differential_base_guid
from sys.database_files where file_id = 1 and type = 0;';
					exec sys.sp_executesql @SQL, N'@BaseLSN numeric(25,0) output, @BaseGUID uniqueidentifier output',
						@BaseLSN = @DifferentialBaseLSN output, @BaseGUID = @DifferentialBaseGUID output;
					if @DifferentialBaseLSN is null or @DifferentialBaseGUID is null or @DifferentialBaseGUID = @PreviousBaseGUID
						throw 50000, 'The fallback full backup did not establish a new differential base. Do not use COPY_ONLY for FullBackupIfNeeded.', 1;
					if @BackupType = 'LOG'
					begin
						select @LastLogBackupLSN = null;
						select @LastLogBackupLSN = last_log_backup_lsn from sys.database_recovery_status where database_id = db_id(@DatabaseName);
						if @LastLogBackupLSN is null
							throw 50000, 'The fallback full backup did not initialize log backups.', 1;
					end
					select @EffectiveBackupType = iif(@BackupType = 'LOG', 'LOG', null), @NeedsFull = 0;
				end
				else
					select @EffectiveBackupType = null;
			end
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
