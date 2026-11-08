/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/020-Backup/modules/1070%20Procedures/z.usp_RestoreDatabase.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/020-Backup/docs/reference/z.usp_RestoreDatabase.md

Plans and restores the latest full, compatible differential and contiguous transaction-log backups.
*/
create or alter procedure z.usp_RestoreDatabase
(
	@BackupPath nvarchar(4000),
	@TargetDatabaseName sysname = null,
	@RecoveryType varchar(10) = 'NORECOVERY',
	@ReplaceExisting bit = 1,
	@DataFolder nvarchar(4000) = null,
	@LogFolder nvarchar(4000) = null,
	@UseDefaultFolder bit = 1,
	@StandbyFolder nvarchar(4000) = null,
	@ShowPlan bit = 0,
	@DropConnections bit = 1,
	@OtherRestoreOptions nvarchar(max) = N'stats = 1'
)
as
begin
	set nocount on;
	set xact_abort off;
	if @@trancount <> 0 throw 50000, 'RestoreDatabase cannot run inside a user transaction.', 1;
	set xact_abort on;
	if @ReplaceExisting is null or @ShowPlan is null or @UseDefaultFolder is null or @DropConnections is null
		throw 50000, 'ReplaceExisting, ShowPlan, UseDefaultFolder and DropConnections must not be null.', 1;
	select @BackupPath = nullif(trim(@BackupPath), N''), @TargetDatabaseName = nullif(trim(@TargetDatabaseName), N''),
		@RecoveryType = upper(trim(@RecoveryType)), @DataFolder = nullif(trim(@DataFolder), N''),
		@LogFolder = nullif(trim(@LogFolder), N''), @StandbyFolder = nullif(trim(@StandbyFolder), N'');
	if @BackupPath is null throw 50000, 'BackupPath is required.', 1;
	if @RecoveryType is null or @RecoveryType not in ('NORECOVERY', 'RECOVERY', 'STANDBY')
		throw 50000, 'RecoveryType must be NORECOVERY, RECOVERY or STANDBY.', 1;
	declare @IsLinux bit = iif(@@version collate Latin1_General_100_CI_AS like '%linux%', 1, 0), @Separator nchar(1), @IsFolder bit = 0, @Path nvarchar(4000), @Folder nvarchar(4000),
		@IsUrl bit, @BackupDevice nvarchar(4), @CrLf nvarchar(2) = nchar(13) + nchar(10), @MoveSeparator nvarchar(4) = N',' + nchar(13) + nchar(10) + nchar(9),
		@FileID int, @BackupID int, @FullID int, @Position int, @HeaderJson nvarchar(max), @FileListJson nvarchar(max), @Sql nvarchar(max),
		@SourceName sysname, @Family uniqueidentifier, @Fork uniqueidentifier, @RequiredLSN numeric(25,0),
		@NextLSN numeric(25,0), @NextID int, @DatabaseID int, @State tinyint, @IsStandby bit, @Continue bit = 0,
		@NativeFamily uniqueidentifier, @NativeFork uniqueidentifier, @HistoryFamily uniqueidentifier, @HistoryFork uniqueidentifier,
		@HistoryLSN numeric(25,0), @HistoryID int, @AnchorHistoryID int, @FullBackupPath nvarchar(4000), @PrimaryPath nvarchar(4000),
		@AnchorBackupSetID int, @AnchorBackupGUID uniqueidentifier, @AnchorCheckpointLSN numeric(25,0),
		@DefaultData nvarchar(4000) = convert(nvarchar(4000), serverproperty('InstanceDefaultDataPath')),
		@DefaultLog nvarchar(4000) = convert(nvarchar(4000), serverproperty('InstanceDefaultLogPath')),
		@Name nvarchar(4000), @Original nvarchar(4000), @Destination nvarchar(4000), @Logical sysname, @Type char(1),
		@Slash int, @Dot int, @FinalOption nvarchar(max), @StandbyFile nvarchar(4000),
		@RestoreCount int, @InitialDatabaseID int, @InitialState tinyint, @InitialStandby bit, @InitialCreateDate datetime,
		@SingleUserSql nvarchar(max), @RestoreAccessSql nvarchar(max), @AccessChanged bit = 0, @InitialUserAccess tinyint, @AccessCreateDate datetime,
		@FastNames bit, @RequestedName sysname = @TargetDatabaseName, @Prefix nvarchar(128), @RequestedPrefix nvarchar(128),
		@DiffID int, @BaseGUID uniqueidentifier, @BaseLSN numeric(25,0), @BaseCopyOnly bit, @HistoryType char(1),
		@CurrentOrdinal int, @StepType varchar(10), @StepSourceName sysname, @FileSourceName sysname, @StepFirstLSN numeric(25,0), @StepLastLSN numeric(25,0),
		@Stage tinyint, @ReadCount int = 0, @FileMapCreated bit = 0, @ScanLSN numeric(25,0), @ScanEnd numeric(25,0), @CandidateType smallint;
	-- Extra WITH options are names with an optional single literal, never executable SQL fragments.
	declare @RestoreOptions table (OptionID int identity primary key, OptionName nvarchar(128) collate Latin1_General_100_BIN2, OptionText nvarchar(max));
	declare @OptInput nvarchar(max) = coalesce(@OtherRestoreOptions, N'') + N',', @OptIndex int = 1, @OptStart int = 1,
		@OptLength int, @OptInQuote bit = 0, @OptChar nchar(1), @OptNext nchar(1), @OptText nvarchar(max), @OptName nvarchar(128),
		@OptOffset int, @OptValue nvarchar(max), @OptValueIndex int, @OptValueLength int, @OptClosed bit;
	select @OptLength = len(@OptInput);
	while @OptIndex <= @OptLength
	begin
		select @OptChar = substring(@OptInput, @OptIndex, 1), @OptNext = substring(@OptInput, @OptIndex + 1, 1);
		if @OptInQuote = 1
		begin
			if @OptChar = N''''
			begin
				if @OptNext = N'''' select @OptIndex += 1;
				else select @OptInQuote = 0;
			end
		end
		else if @OptChar = N'''' select @OptInQuote = 1;
		else if @OptChar = N';' or (@OptChar = N'-' and @OptNext = N'-') or (@OptChar = N'/' and @OptNext = N'*') or (@OptChar = N'*' and @OptNext = N'/')
			throw 50000, 'OtherRestoreOptions cannot contain statement separators or comments outside quoted literals.', 1;
		else if @OptChar = N','
		begin
			select @OptText = substring(@OptInput, @OptStart, @OptIndex - @OptStart), @OptStart = @OptIndex + 1;
			while unicode(left(@OptText, 1)) in (9, 10, 11, 12, 13, 32) select @OptText = substring(@OptText, 2, len(@OptText + N'#'));
			while unicode(right(@OptText, 1)) in (9, 10, 11, 12, 13, 32) select @OptText = left(@OptText, len(@OptText + N'#') - 2);
			if @OptText = N''
			begin
				if @OptIndex <> @OptLength or @OptStart <> 2
					if nullif(trim(translate(@OtherRestoreOptions, nchar(9) + nchar(10) + nchar(11) + nchar(12) + nchar(13), N'     ')), N'') is not null
						throw 50000, 'OtherRestoreOptions contains an empty option.', 1;
			end
			else
			begin
				select @OptOffset = 1;
				while substring(@OptText, @OptOffset, 1) collate Latin1_General_100_BIN2 like N'[A-Za-z0-9_]'
					and @OptOffset <= len(@OptText) select @OptOffset += 1;
				if @OptOffset = 1 or @OptOffset > 129 or left(@OptText, 1) collate Latin1_General_100_BIN2 not like N'[A-Za-z_]'
					throw 50000, 'OtherRestoreOptions requires an ASCII option name of at most 128 characters.', 1;
				select @OptName = upper(left(@OptText, @OptOffset - 1) collate Latin1_General_100_CI_AS),
					@OptValue = substring(@OptText, @OptOffset, len(@OptText));
				while unicode(left(@OptValue, 1)) in (9, 10, 11, 12, 13, 32) select @OptValue = substring(@OptValue, 2, len(@OptValue + N'#'));
				if @OptValue <> N''
				begin
					if left(@OptValue, 1) <> N'=' throw 50000, 'OtherRestoreOptions accepts only flags or option = literal.', 1;
					select @OptValue = substring(@OptValue, 2, len(@OptValue));
					while unicode(left(@OptValue, 1)) in (9, 10, 11, 12, 13, 32) select @OptValue = substring(@OptValue, 2, len(@OptValue + N'#'));
					if @OptValue = N'' throw 50000, 'OtherRestoreOptions contains a missing option value.', 1;
					select @OptValueIndex = iif(left(@OptValue, 1) in (N'N', N'n') and substring(@OptValue, 2, 1) = N'''', 2, 1),
						@OptValueLength = len(@OptValue + N'#') - 1, @OptClosed = 0;
					if substring(@OptValue, @OptValueIndex, 1) = N''''
					begin
						select @OptValueIndex += 1;
						while @OptValueIndex <= @OptValueLength
						begin
							if substring(@OptValue, @OptValueIndex, 1) = N''''
							begin
								if substring(@OptValue, @OptValueIndex + 1, 1) = N'''' select @OptValueIndex += 1;
								else
								begin
									if @OptValueIndex <> @OptValueLength throw 50000, 'OtherRestoreOptions requires a single literal value.', 1;
									select @OptClosed = 1;
								end
							end
							select @OptValueIndex += 1;
						end
						if @OptClosed = 0 throw 50000, 'OtherRestoreOptions contains an unclosed string literal.', 1;
					end
					else if not
					(
						(@OptValue collate Latin1_General_100_BIN2 not like N'%[^0-9.+-]%' and try_convert(decimal(38, 10), @OptValue) is not null)
						or (left(@OptValue, 2) = N'0x' and len(@OptValue) > 2 and substring(@OptValue, 3, len(@OptValue)) collate Latin1_General_100_BIN2 not like N'%[^0-9A-Fa-f]%')
						or (left(@OptValue, 1) collate Latin1_General_100_BIN2 like N'[A-Za-z_]' and @OptValue collate Latin1_General_100_BIN2 not like N'%[^A-Za-z0-9_]%')
					)
						throw 50000, 'OtherRestoreOptions values must be numeric, hexadecimal, quoted strings or single keywords.', 1;
				end
				select @OptText = left(@OptText, @OptOffset - 1) + iif(@OptValue = N'', N'', N' = ' + @OptValue);
				if @OptName in (N'FILE', N'FILEGROUP', N'READ_WRITE_FILEGROUPS', N'PAGE', N'PARTIAL', N'MOVE', N'REPLACE', N'RESTRICTED_USER',
					N'RECOVERY', N'NORECOVERY', N'STANDBY', N'STOPAT', N'STOPATMARK', N'STOPBEFOREMARK', N'DATABASE_SNAPSHOT', N'METADATA_ONLY', N'SNAPSHOT_RESTORE_PHASE', N'ONLINE')
					throw 50000, 'OtherRestoreOptions cannot override backup selection, file mapping, recovery or partial-restore planning.', 1;
				select @OptName = case @OptName when N'NO_CHECKSUM' then N'CHECKSUM' when N'CONTINUE_AFTER_ERROR' then N'STOP_ON_ERROR'
					when N'NOREWIND' then N'REWIND' when N'NOUNLOAD' then N'UNLOAD'
					when N'NEW_BROKER' then N'ENABLE_BROKER' when N'ERROR_BROKER_CONVERSATIONS' then N'ENABLE_BROKER' else @OptName end;
				insert @RestoreOptions (OptionName, OptionText) values (@OptName, @OptText);
			end
		end
		select @OptIndex += 1;
	end
	if @OptInQuote = 1 throw 50000, 'OtherRestoreOptions contains an unclosed string literal.', 1;
	delete t from @RestoreOptions t where exists(select * from @RestoreOptions s where s.OptionName = t.OptionName and s.OptionID > t.OptionID);
	select @OtherRestoreOptions = string_agg(OptionText, N', ') within group (order by OptionID) from @RestoreOptions;
	select @Separator = iif(@IsLinux = 1, N'/', N'\'),
		@IsUrl = iif(left(@BackupPath, 7) collate Latin1_General_100_CI_AS = N'http://'
			or left(@BackupPath, 8) collate Latin1_General_100_CI_AS = N'https://'
			or left(@BackupPath, 5) collate Latin1_General_100_CI_AS = N's3://', 1, 0);
	select @BackupDevice = iif(@IsUrl = 1, N'url', N'disk');
	if @IsLinux = 0
	begin
		if @IsUrl = 0 select @BackupPath = replace(@BackupPath, N'/', N'\');
		select @DataFolder = replace(@DataFolder, N'/', N'\'), @LogFolder = replace(@LogFolder, N'/', N'\'), @StandbyFolder = replace(@StandbyFolder, N'/', N'\');
	end
	if @RecoveryType = 'STANDBY' and @StandbyFolder is not null and not exists(select * from sys.dm_os_file_exists(@StandbyFolder) where file_is_a_directory = 1)
		throw 50000, 'The explicit StandbyFolder does not exist or is inaccessible.', 1;
	-- Remote paths identify exactly one object; only local paths can be tested or enumerated as folders.
	if @IsUrl = 0
	begin
		select @IsFolder = file_is_a_directory from sys.dm_os_file_exists(@BackupPath);
		if @IsFolder is null throw 50000, 'BackupPath is inaccessible.', 1;
		if @IsFolder = 0 and not exists(select * from sys.dm_os_file_exists(@BackupPath) where file_exists = 1)
			throw 50000, 'BackupPath does not identify an accessible file or folder.', 1;
	end

	create table #Folders (Path nvarchar(4000) collate Latin1_General_100_BIN2 not null, Processed bit not null default 0);
	create table #Files
	(
		FileID int identity(1,1) not null primary key,
		Path nvarchar(4000) collate Latin1_General_100_BIN2 not null,
		FileName nvarchar(4000), Prefix nvarchar(128), Stamp datetime2(6), Kind smallint,
		Inspected bit not null default 0, ReadError nvarchar(2048)
	);
	if @IsFolder = 1
	begin
		insert #Folders (Path) values (@BackupPath);
		while exists(select * from #Folders where Processed = 0)
		begin
			if (select count(*) from #Folders) > 4096 throw 50000, 'Backup discovery exceeds 4096 directories; choose a narrower folder.', 1;
			select top (1) @Folder = Path from #Folders where Processed = 0 order by Path;
			insert #Folders (Path)
				select distinct e.full_filesystem_path from sys.dm_os_enumerate_filesystem(@Folder, N'*') e
				where e.is_directory = 1 and e.file_or_directory_name not in (N'.', N'..')
					and not exists(select * from #Folders f where f.Path = e.full_filesystem_path collate Latin1_General_100_BIN2);
			insert #Files (Path)
				select distinct e.full_filesystem_path from sys.dm_os_enumerate_filesystem(@Folder, N'*') e
				where e.is_directory = 0 and not exists(select * from #Files f where f.Path = e.full_filesystem_path collate Latin1_General_100_BIN2);
			update #Folders set Processed = 1 where Path = @Folder collate Latin1_General_100_BIN2;
		end
	end
	else insert #Files (Path) values (@BackupPath);
	if not exists(select * from #Files) throw 50000, 'No backup files were found.', 1;

	create table #Label
	(
		MediaName nvarchar(128), MediaSetId uniqueidentifier, FamilyCount int, FamilySequenceNumber int,
		MediaFamilyId uniqueidentifier, MediaSequenceNumber int, MediaLabelPresent tinyint, MediaDescription nvarchar(255),
		SoftwareName nvarchar(128), SoftwareVendorId int, MediaDate datetime, Mirror_Count int, IsCompressed bit
	);
	create table #Backups
	(
		BackupID int identity(1,1) not null primary key,
		FileID int not null,
		Position int not null,
		BackupType smallint not null,
		DatabaseName sysname,
		FamilyGUID uniqueidentifier,
		FirstFork uniqueidentifier,
		LastFork uniqueidentifier,
		ForkPointLSN numeric(25,0),
		FirstLSN numeric(25,0),
		LastLSN numeric(25,0),
		BackupFinishDate datetime,
		BackupSetGUID uniqueidentifier,
		SoftwareVersionMajor int,
		IsDamaged bit,
		IsSnapshot bit,
		HasIncompleteMetaData bit,
		CheckpointLSN numeric(25,0),
		DifferentialBaseLSN numeric(25,0),
		DifferentialBaseGUID uniqueidentifier,
		IsCopyOnly bit
	);
	-- Names emitted by usp_BackupDatabase allow candidate ordering without opening old media.
	update #Files set FileName = right(replace(Path, N'\', N'/'), charindex(N'/', reverse(replace(Path, N'\', N'/')) + N'/') - 1);
	update f set Prefix = left(FileName, case when len(FileName) > e.ExtensionLength + 23 then len(FileName) - e.ExtensionLength - 23 else 0 end), Stamp = d.BackupTime, Kind = e.Kind
		from #Files f
			cross apply (values (case when right(FileName, 5) = N'.diff' then 5 else 4 end,
				case when right(FileName, 5) = N'.diff' then 5 when right(FileName, 4) = N'.bak' then 1 when right(FileName, 4) = N'.trn' then 2 end)) e(ExtensionLength, Kind)
			cross apply (values (substring(FileName, len(FileName) - e.ExtensionLength - 21, 22))) n(Stamp)
			cross apply (values (try_convert(datetime2(6), substring(n.Stamp, 1, 4) + N'-' + substring(n.Stamp, 5, 2) + N'-' + substring(n.Stamp, 7, 2)
				+ N'T' + substring(n.Stamp, 10, 2) + N':' + substring(n.Stamp, 12, 2) + N':' + substring(n.Stamp, 14, 2) + N'.' + substring(n.Stamp, 17, 6), 126))) d(BackupTime)
		where e.Kind is not null and len(FileName) > e.ExtensionLength + 23 and len(FileName) <= e.ExtensionLength + 23 + 128
			and substring(FileName, len(FileName) - e.ExtensionLength - 22, 1) = N'_'
			and substring(n.Stamp, 9, 1) = N'_' and substring(n.Stamp, 16, 1) = N'_'
			and replace(n.Stamp, N'_', N'') collate Latin1_General_100_BIN2 not like N'%[^0-9]%'
			and datalength(replace(n.Stamp, N'_', N'')) = 40 and d.BackupTime is not null;
	-- Multiple prefixes can represent one source renamed between backups; inspect headers to retain its complete family chain.
	select @FastNames = iif(@IsFolder = 1 and not exists(select * from #Files where Kind is null)
		and (select count(distinct Prefix) from #Files) = 1, 1, 0),
		@RequestedPrefix = replace(translate(@RequestedName, N'<>:"/\?*' + nchar(9) + nchar(10) + nchar(11) + nchar(12) + nchar(13), N'             '), N' ', N'_'), @DatabaseID = db_id(@TargetDatabaseName);
	DiscoverSource:
	-- A misleading managed name restarts planning from the cached headers, without re-reading them.
	if @FileMapCreated = 1
	begin
		drop table #FileMap;
		select @FileMapCreated = 0;
	end
	select @TargetDatabaseName = @RequestedName, @DatabaseID = db_id(@RequestedName), @State = null, @IsStandby = null,
		@SourceName = null, @Family = null, @FullID = null, @DiffID = null, @FullBackupPath = null,
		@BaseGUID = null, @BaseLSN = null, @BaseCopyOnly = null, @HistoryType = null, @HistoryID = null, @HistoryLSN = null,
		@HistoryFamily = null, @HistoryFork = null, @NativeFamily = null, @NativeFork = null, @RequiredLSN = null, @Fork = null;
	select @State = state, @IsStandby = is_in_standby from sys.databases where database_id = @DatabaseID;
	select @Continue = iif(@State = 1 or @IsStandby = 1, 1, 0);
	if @Continue = 1
		select top (1) @SourceName = b.database_name, @Family = b.family_guid from msdb.dbo.restorehistory r
			join msdb.dbo.backupset b on b.backup_set_id = r.backup_set_id where r.destination_database_name = @TargetDatabaseName order by r.restore_history_id desc;

	-- General names require a header inventory. Managed names initially open only a full candidate.
	while 1 = 1
	begin
		select @FileID = null;
		if @FastNames = 0
			select top (1) @FileID = FileID, @Path = Path from #Files where Inspected = 0 order by Path;
		else if @Continue = 0 and @FullID is null
			select top (1) @FileID = FileID, @Path = Path from #Files where Inspected = 0 and Kind = 1
				order by iif(Prefix = @RequestedPrefix, 0, 1), Stamp desc, Path;
		if @FileID is null break;
		update #Files set Inspected = 1 where FileID = @FileID;
		begin try
			select @ReadCount += 1;
			exec z.usp_ReadBackupHeader @BackupFile = @Path, @HeaderJson = @HeaderJson output, @ReturnResult = 0;
			if (select count(*) from z.fn_DecodeBackupHeader(@HeaderJson)) <> 1
				throw 50000, 'Each selected backup file must contain exactly one backup set.', 1;
			insert #Backups (FileID, Position, BackupType, DatabaseName, FamilyGUID, FirstFork, LastFork, ForkPointLSN, FirstLSN, LastLSN,
				BackupFinishDate, BackupSetGUID, SoftwareVersionMajor, IsDamaged, IsSnapshot, HasIncompleteMetaData, CheckpointLSN, DifferentialBaseLSN, DifferentialBaseGUID, IsCopyOnly)
				select @FileID, Position, BackupType, DatabaseName, FamilyGUID, FirstRecoveryForkID, RecoveryForkID, ForkPointLSN, FirstLSN, LastLSN,
					BackupFinishDate, BackupSetGUID, SoftwareVersionMajor, IsDamaged, IsSnapshot, HasIncompleteMetaData, CheckpointLSN, DifferentialBaseLSN, DifferentialBaseGUID, IsCopyOnly
				from z.fn_DecodeBackupHeader(@HeaderJson);
		end try
		begin catch
			if @IsFolder = 0 or @FastNames = 1 throw;
			update #Files set ReadError = error_message() where FileID = @FileID;
		end catch
		if @FastNames = 1
		begin
			if exists(select * from #Backups b join #Files f on f.FileID = b.FileID where b.FileID = @FileID
				and (b.BackupType <> f.Kind or b.DatabaseName is null or (f.Prefix = @RequestedPrefix and b.DatabaseName <> @RequestedName) or replace(translate(b.DatabaseName, N'<>:"/\?*' + nchar(9) + nchar(10) + nchar(11) + nchar(12) + nchar(13), N'             '), N' ', N'_') <> f.Prefix))
				select @FastNames = 0;
			else select @FullID = BackupID from #Backups where FileID = @FileID and BackupType = 1;
		end
	end
	if @Continue = 0 or @SourceName is null
	begin
		select @FullID = null;
		select top (1) @FullID = b.BackupID, @FullBackupPath = f.Path, @SourceName = b.DatabaseName, @Family = b.FamilyGUID
			from #Backups b join #Files f on f.FileID = b.FileID where b.BackupType = 1
			order by iif(b.DatabaseName = @RequestedName, 0, 1), b.BackupFinishDate desc, b.LastLSN desc, f.Path;
		if @FullID is null and @IsFolder = 0
			select top (1) @SourceName = DatabaseName, @Family = FamilyGUID from #Backups order by BackupID;
	end
	if @SourceName is null or @Family is null throw 50000, 'No readable backup source identity could be selected.', 1;
	if @TargetDatabaseName is null and @FullID is null throw 50000, 'TargetDatabaseName is required when providing a log or differential file.', 1;
	select @TargetDatabaseName = coalesce(@TargetDatabaseName, @SourceName), @DatabaseID = db_id(coalesce(@TargetDatabaseName, @SourceName));
	if @TargetDatabaseName in (N'master', N'model', N'msdb', N'tempdb') or @DatabaseID <= 4 or @TargetDatabaseName = db_name()
		throw 50000, 'System databases and the database hosting this procedure cannot be restore targets.', 1;
	if exists(select * from sys.databases where database_id = @DatabaseID and (source_database_id is not null or group_database_id is not null))
		throw 50000, 'Database snapshots and availability-group databases are not supported restore targets.', 1;
	select @State = state, @IsStandby = is_in_standby from sys.databases where database_id = @DatabaseID;
	select @InitialDatabaseID = @DatabaseID, @InitialState = @State, @InitialStandby = @IsStandby,
		@Continue = iif(@State = 1 or @IsStandby = 1, 1, 0);
	select @InitialCreateDate = create_date, @InitialUserAccess = user_access from sys.databases where database_id = @DatabaseID;
	if @DatabaseID is not null and @Continue = 0 and @ReplaceExisting = 0 throw 50000, 'The destination exists and ReplaceExisting is disabled.', 1;
	if @Continue = 0 and @FullID is null throw 50000, 'A full backup is required to initialize or replace the destination.', 1;
	if @Continue = 0
	begin
		if not exists(select * from #Backups where BackupID = @FullID and BackupType = 1 and DatabaseName is not null and FamilyGUID is not null
			and BackupFinishDate is not null and BackupSetGUID is not null and FirstLSN is not null and LastLSN is not null and FirstLSN < LastLSN
			and FirstFork is not null and LastFork = FirstFork and ForkPointLSN is null and isnull(IsDamaged, 1) = 0 and isnull(IsSnapshot, 1) = 0 and isnull(HasIncompleteMetaData, 1) = 0)
			throw 50000, 'The selected full has incomplete, damaged, snapshot or unsupported recovery-fork metadata.', 1;
		select @BaseGUID = BackupSetGUID, @BaseLSN = CheckpointLSN, @BaseCopyOnly = IsCopyOnly from #Backups where BackupID = @FullID;
	end

	create table #FileMap
	(
		FileID bigint not null,
		LogicalName sysname not null,
		Type char(1) not null,
		UniqueID uniqueidentifier,
		OriginalPath nvarchar(4000) collate Latin1_General_100_BIN2,
		DestinationPath nvarchar(4000) collate Latin1_General_100_BIN2,
		AddedOrdinal int not null default 0,
		SourceDatabaseName sysname
	);
	select @FileMapCreated = 1;
	if @Continue = 1
	begin
		select @PrimaryPath = physical_name from sys.master_files where database_id = @DatabaseID and file_id = 1;
		select @NativeFamily = family_guid, @NativeFork = recovery_fork_guid from sys.database_recovery_status where database_id = @DatabaseID;
		select top (1) @HistoryID = r.restore_history_id, @HistoryFamily = b.family_guid, @HistoryFork = b.last_recovery_fork_guid,
			@HistoryLSN = b.last_lsn, @HistoryType = b.type, @SourceName = b.database_name from msdb.dbo.restorehistory r join msdb.dbo.backupset b on b.backup_set_id = r.backup_set_id
			where r.destination_database_name = @TargetDatabaseName order by r.restore_history_id desc;
		if @HistoryID is null or @HistoryFamily <> @Family or @HistoryFamily is null or exists
			(select * from msdb.dbo.restorehistory where restore_history_id = @HistoryID and
				(restore_type is null or restore_type not in ('D', 'I', 'L') or recovery is null or recovery <> 0 or stop_at is not null or stop_at_mark_name is not null or stop_before = 1))
			throw 50000, 'A compatible, complete, unrecovered restore history is required for continuation.', 1;
		if exists(select * from msdb.dbo.restorehistory r join sys.databases d on d.database_id = @DatabaseID
			where r.restore_history_id = @HistoryID and (r.restore_date is null or d.create_date is null or (@HistoryType <> 'D' and r.restore_date < d.create_date)))
			throw 50000, 'Destination was created or renamed after its recorded restore; continuation identity is uncertain.', 1;
		if @NativeFamily is not null and @NativeFamily <> @Family throw 50000, 'Destination backup family does not match the source.', 1;
		if @HistoryType = 'D'
			select @BaseGUID = b.backup_set_uuid, @BaseLSN = b.checkpoint_lsn, @BaseCopyOnly = b.is_copy_only from msdb.dbo.restorehistory r
				join msdb.dbo.backupset b on b.backup_set_id = r.backup_set_id where r.restore_history_id = @HistoryID;
		select @FullBackupPath = null;

		-- Log history may map only the log file. Bind each file to its latest mapping in this full-restore epoch.
		select @AnchorHistoryID = null, @AnchorBackupSetID = null, @AnchorBackupGUID = null, @AnchorCheckpointLSN = null;
		select top (1) @AnchorHistoryID = r.restore_history_id, @AnchorBackupSetID = b.backup_set_id,
			@AnchorBackupGUID = b.backup_set_uuid, @AnchorCheckpointLSN = b.checkpoint_lsn from msdb.dbo.restorehistory r
			join msdb.dbo.backupset b on b.backup_set_id = r.backup_set_id
			where r.destination_database_name = @TargetDatabaseName and r.restore_history_id <= @HistoryID and r.restore_type = 'D'
				and r.recovery = 0 and r.restore_date is not null and r.stop_at is null and r.stop_at_mark_name is null and isnull(r.stop_before, 0) = 0
				and b.type = 'D' and b.family_guid = @Family and b.last_recovery_fork_guid = @HistoryFork
			order by r.restore_history_id desc;
		if @AnchorHistoryID is null throw 50000, 'A compatible full-restore history anchor is required for continuation.', 1;
		if exists
		(
			select * from sys.master_files m
				outer apply
				(
					select top (1) b.file_guid FileGUID, p.PhysicalPath
					from msdb.dbo.restorehistory r join msdb.dbo.backupset h on h.backup_set_id = r.backup_set_id
						join msdb.dbo.backupfile b on b.backup_set_id = r.backup_set_id
						join msdb.dbo.restorefile f on f.restore_history_id = r.restore_history_id and f.file_number = b.file_number
						cross apply (values (case
							when @IsLinux = 1 and left(f.destination_phys_name, 1) = N'/' then f.destination_phys_name
							when @IsLinux = 0 and (substring(f.destination_phys_name, 2, 1) = N':' or left(f.destination_phys_name, 2) = N'\\') then f.destination_phys_name
							else coalesce(f.destination_phys_drive, N'')
								+ iif(right(f.destination_phys_drive, 1) in (N'/', N'\') or left(f.destination_phys_name, 1) in (N'/', N'\'), N'', @Separator)
								+ f.destination_phys_name end)) p(PhysicalPath)
					where r.destination_database_name = @TargetDatabaseName and r.restore_history_id between @AnchorHistoryID and @HistoryID
						and r.restore_type in ('D', 'I', 'L') and r.recovery = 0 and b.file_number = m.file_id
						and h.family_guid = @Family and h.last_recovery_fork_guid = @HistoryFork
					order by r.restore_history_id desc
				) a
				outer apply
				(
					select top (1) b.file_guid FileGUID, b.create_lsn CreateLSN, b.drop_lsn DropLSN
					from msdb.dbo.restorehistory r join msdb.dbo.backupset h on h.backup_set_id = r.backup_set_id
						join msdb.dbo.backupfile b on b.backup_set_id = r.backup_set_id
					where r.destination_database_name = @TargetDatabaseName and r.restore_history_id between @AnchorHistoryID and @HistoryID
						and r.restore_type in ('D', 'I', 'L') and r.recovery = 0 and b.file_number = m.file_id
						and h.family_guid = @Family and h.last_recovery_fork_guid = @HistoryFork
					order by r.restore_history_id desc
				) v
			where m.database_id = @DatabaseID and m.type in (0, 1) and case when
				(a.FileGUID = m.file_guid and
					(case when @IsLinux = 1 then a.PhysicalPath else lower(replace(a.PhysicalPath, N'/', N'\')) end) collate Latin1_General_100_BIN2 =
					(case when @IsLinux = 1 then m.physical_name else lower(replace(m.physical_name, N'/', N'\')) end) collate Latin1_General_100_BIN2)
				or
				-- LOG restorefile can omit a newly created data file. Prove its native GUID/creation LSN and introducing backup instead.
				(a.FileGUID is null and v.FileGUID = m.file_guid and v.CreateLSN = m.create_lsn and m.create_lsn > 0 and isnull(v.DropLSN, 0) = 0
					and not exists(select * from msdb.dbo.backupfile f where f.backup_set_id = @AnchorBackupSetID and (f.file_number = m.file_id or f.file_guid = m.file_guid))
					and exists
					(
						select * from msdb.dbo.restorehistory r join msdb.dbo.backupset h on h.backup_set_id = r.backup_set_id
							join msdb.dbo.backupfile f on f.backup_set_id = r.backup_set_id
						where r.destination_database_name = @TargetDatabaseName and r.restore_history_id between @AnchorHistoryID and @HistoryID and r.recovery = 0
							and h.family_guid = @Family and h.first_recovery_fork_guid = @HistoryFork and h.last_recovery_fork_guid = @HistoryFork
							and f.file_number = m.file_id and f.file_guid = m.file_guid and f.create_lsn = m.create_lsn
							and ((r.restore_type = 'L' and h.type = 'L' and f.create_lsn >= h.first_lsn and f.create_lsn < h.last_lsn)
								or (r.restore_type = 'I' and h.type = 'I' and h.differential_base_guid = @AnchorBackupGUID and h.differential_base_lsn = @AnchorCheckpointLSN))
					)) then 1 else 0 end = 0
		)
			throw 50000, 'Restore history cannot be anchored to every destination file path and identity.', 1;
		select @RequiredLSN = min(redo_start_lsn) from sys.master_files where database_id = @DatabaseID and type = 0;
		select top (1) @Fork = redo_start_fork_guid from sys.master_files where database_id = @DatabaseID and type = 0 and redo_start_lsn is not null order by file_id;
		if exists(select * from sys.master_files where database_id = @DatabaseID and type = 0 and redo_start_lsn is not null
			and (redo_start_fork_guid is null or redo_start_fork_guid <> @Fork))
			throw 50000, 'The destination has inconsistent file recovery forks.', 1;
		if @IsStandby = 1
		begin
			if @NativeFamily is null or @NativeFamily <> @HistoryFamily or @NativeFork is null or @NativeFork <> @HistoryFork
				throw 50000, 'Standby recovery identity cannot be bound to its recorded restore.', 1;
			select @RequiredLSN = @HistoryLSN, @Fork = @NativeFork;
		end
		if @RequiredLSN is null or @Fork is null or @HistoryLSN is null or @HistoryFork is null or @Fork <> @HistoryFork
			throw 50000, 'Destination redo position or recovery fork is unavailable or inconsistent.', 1;
		-- Native redo metadata is authoritative while RESTORING; history must never advance it.
		insert #FileMap (FileID, LogicalName, Type, UniqueID, OriginalPath, DestinationPath, SourceDatabaseName)
			select file_id, name, iif(type = 1, 'L', 'D'), file_guid, physical_name, physical_name, @SourceName from sys.master_files
			where database_id = @DatabaseID and type in (0, 1);
		if exists(select * from sys.master_files where database_id = @DatabaseID and type not in (0, 1))
			throw 50000, 'Only ROWS and LOG layouts support continuation through this procedure.', 1;
		-- Supplied folders govern new files only; current physical paths remain unchanged.
		if @FullBackupPath is null
			select top (1) @FullBackupPath = m.physical_device_name from msdb.dbo.restorehistory r
				join msdb.dbo.backupset b on b.backup_set_id = r.backup_set_id
				join msdb.dbo.backupmediafamily m on m.media_set_id = b.media_set_id
				where r.destination_database_name = @TargetDatabaseName and r.restore_history_id <= @HistoryID and r.restore_type = 'D'
					and b.family_guid = @Family and b.type = 'D' and m.family_sequence_number = 1 and m.mirror = 0
				order by r.restore_history_id desc;
	end
	else
	begin
		select @RequiredLSN = LastLSN, @Fork = LastFork, @Position = Position from #Backups where BackupID = @FullID;
		exec z.usp_ReadBackupFileList @BackupFile = @FullBackupPath, @Position = @Position, @FileListJson = @FileListJson output, @ReturnResult = 0;
		if exists(select * from z.fn_DecodeBackupFileList(@FileListJson) where Type is null or Type not in ('D', 'L') or IsPresent = 0 or LogicalName is null
			or FileID is null or UniqueID is null or PhysicalName is null or DropLSN > 0)
			throw 50000, 'Only complete ROWS and LOG file layouts are supported; FILESTREAM and partial layouts require an explicit restore.', 1;
		insert #FileMap (FileID, LogicalName, Type, UniqueID, OriginalPath, AddedOrdinal, SourceDatabaseName)
			select FileID, LogicalName, Type, UniqueID, PhysicalName, 1, @SourceName from z.fn_DecodeBackupFileList(@FileListJson);
		if not exists(select * from #FileMap where FileID = 1 and Type = 'D') throw 50000, 'The backup primary data file is missing.', 1;

	end

	-- Differential discovery precedes logs so its later LSN avoids reading/replaying covered logs.
	select @Prefix = replace(translate(@SourceName, N'<>:"/\?*' + nchar(9) + nchar(10) + nchar(11) + nchar(12) + nchar(13), N'             '), N' ', N'_'), @Stage = 5;
	while @Stage in (5, 2)
	begin
		while 1 = 1
		begin
			select @FileID = null;
			if @FastNames = 0
				select top (1) @FileID = FileID, @Path = Path from #Files where Inspected = 0 order by Path;
			else if @Stage = 2 or (@BaseGUID is not null and @BaseCopyOnly = 0)
				select top (1) @FileID = FileID, @Path = Path from #Files
					where Inspected = 0 and Kind = @Stage and Prefix = @Prefix order by Stamp desc, Path;
			if @FileID is null break;
			update #Files set Inspected = 1 where FileID = @FileID;
			begin try
				select @ReadCount += 1;
				exec z.usp_ReadBackupHeader @BackupFile = @Path, @HeaderJson = @HeaderJson output, @ReturnResult = 0;
				if (select count(*) from z.fn_DecodeBackupHeader(@HeaderJson)) <> 1
					throw 50000, 'Each selected backup file must contain exactly one backup set.', 1;
				insert #Backups (FileID, Position, BackupType, DatabaseName, FamilyGUID, FirstFork, LastFork, ForkPointLSN, FirstLSN, LastLSN,
					BackupFinishDate, BackupSetGUID, SoftwareVersionMajor, IsDamaged, IsSnapshot, HasIncompleteMetaData, CheckpointLSN, DifferentialBaseLSN, DifferentialBaseGUID, IsCopyOnly)
					select @FileID, Position, BackupType, DatabaseName, FamilyGUID, FirstRecoveryForkID, RecoveryForkID, ForkPointLSN, FirstLSN, LastLSN,
						BackupFinishDate, BackupSetGUID, SoftwareVersionMajor, IsDamaged, IsSnapshot, HasIncompleteMetaData, CheckpointLSN, DifferentialBaseLSN, DifferentialBaseGUID, IsCopyOnly
						from z.fn_DecodeBackupHeader(@HeaderJson);
			end try
			begin catch
				if @IsFolder = 0 or @FastNames = 1 throw;
				update #Files set ReadError = error_message() where FileID = @FileID;
			end catch
			if @FastNames = 1 and exists(select * from #Backups b join #Files f on f.FileID = b.FileID where b.FileID = @FileID
				and (b.BackupType <> f.Kind or b.DatabaseName is null or replace(translate(b.DatabaseName, N'<>:"/\?*' + nchar(9) + nchar(10) + nchar(11) + nchar(12) + nchar(13), N'             '), N' ', N'_') <> f.Prefix))
			begin
				select @FastNames = 0;
				goto DiscoverSource;
			end
			if @FastNames = 1 and @Stage = 5 and exists(select * from #Backups where FileID = @FileID and BackupType = 5
				and FamilyGUID = @Family and FirstFork = @Fork and LastFork = @Fork and DifferentialBaseGUID = @BaseGUID and DifferentialBaseLSN = @BaseLSN
				and LastLSN > @RequiredLSN and @BaseCopyOnly = 0) break;
			if @FastNames = 1 and @Stage = 2 and exists(select * from #Backups where FileID = @FileID and BackupType = 2 and FamilyGUID = @Family and FirstFork = @Fork and LastFork = @Fork)
			begin
				-- Stop only after the inspected ranges bridge the base to the newest inspected log.
				select @ScanLSN = @RequiredLSN;
				while 1 = 1
				begin
					select @ScanEnd = max(LastLSN) from #Backups where BackupType = 2 and FamilyGUID = @Family and FirstFork = @Fork and LastFork = @Fork
						and FirstLSN <= @ScanLSN and LastLSN > @ScanLSN;
					if @ScanEnd is null break;
					select @ScanLSN = @ScanEnd;
				end
				if not exists(select * from #Backups where BackupType = 2 and FamilyGUID = @Family and FirstFork = @Fork and LastFork = @Fork and LastLSN > @ScanLSN) break;
			end
		end
		if @Stage = 5
		begin
			select top (1) @DiffID = b.BackupID from #Backups b join #Files f on f.FileID = b.FileID
				where b.BackupType = 5 and b.FamilyGUID = @Family and b.FirstFork = @Fork and b.LastFork = @Fork
					and b.DifferentialBaseGUID = @BaseGUID and b.DifferentialBaseLSN = @BaseLSN and @BaseCopyOnly = 0 and b.LastLSN > @RequiredLSN
				order by b.BackupFinishDate desc, b.LastLSN desc, f.Path;
			if @DiffID is not null select @RequiredLSN = LastLSN from #Backups where BackupID = @DiffID;
			if @IsFolder = 0 and exists(select * from #Backups where BackupType = 5) and @DiffID is null
				throw 50000, 'The differential requires a matching unrecovered full backup with no intervening log restore.', 1;
			select @Stage = 2;
		end
		else select @Stage = 0;
	end
	if @IsFolder = 0 and exists(select * from #Backups where BackupType not in (1, 2, 5) or FamilyGUID is null or FamilyGUID <> @Family
		or FirstFork is null or LastFork is null or FirstFork <> @Fork or LastFork <> @Fork or ForkPointLSN is not null
		or DatabaseName is null or BackupFinishDate is null or BackupSetGUID is null or FirstLSN is null or LastLSN is null or FirstLSN >= LastLSN
		or isnull(IsDamaged, 1) <> 0 or isnull(IsSnapshot, 1) <> 0 or isnull(HasIncompleteMetaData, 1) <> 0)
		throw 50000, 'The supplied backup file has invalid metadata or is incompatible with the selected database family or recovery fork.', 1;
	-- Other sources, recovery branches and older covered media do not participate in this restore.
	delete from #Backups where BackupID <> isnull(@FullID, -1) and BackupID <> isnull(@DiffID, -1)
		and (FamilyGUID <> @Family or FamilyGUID is null or FirstFork <> @Fork or LastFork <> @Fork);
	delete b from #Backups b where exists(select * from #Backups d where d.BackupSetGUID = b.BackupSetGUID and d.BackupID < b.BackupID)
		and b.BackupID <> isnull(@FullID, -1) and b.BackupID <> isnull(@DiffID, -1);

	create table #MediaPlan (Ordinal int identity(1,1) not null primary key, BackupID int, BackupType varchar(10), BackupFile nvarchar(4000), Position int, FirstLSN numeric(25,0), LastLSN numeric(25,0), Command nvarchar(max));
	if @Continue = 0
		insert #MediaPlan (BackupID, BackupType, BackupFile, Position, FirstLSN, LastLSN)
			select b.BackupID, 'FULL', f.Path, b.Position, b.FirstLSN, b.LastLSN from #Backups b join #Files f on f.FileID = b.FileID where b.BackupID = @FullID;
	if @DiffID is not null
		insert #MediaPlan (BackupID, BackupType, BackupFile, Position, FirstLSN, LastLSN)
			select b.BackupID, 'DIFF', f.Path, b.Position, b.FirstLSN, b.LastLSN from #Backups b join #Files f on f.FileID = b.FileID where b.BackupID = @DiffID;
	while exists(select * from #Backups where BackupType = 2 and LastLSN > @RequiredLSN)
	begin
		if exists(select * from #Backups where BackupType = 2 and LastLSN > @RequiredLSN and FirstFork <> @Fork)
			throw 50000, 'A pending log backup belongs to a different recovery fork.', 1;
		select @NextID = null;
		select top (1) @NextID = BackupID, @NextLSN = LastLSN from #Backups
			where BackupType = 2 and FirstFork = @Fork and FirstLSN <= @RequiredLSN and LastLSN > @RequiredLSN
			order by LastLSN desc, FirstLSN, (select Path from #Files where FileID = #Backups.FileID);
		if @NextID is null throw 50000, 'The available transaction-log backups have a gap after the required restore LSN.', 1;

		insert #MediaPlan (BackupID, BackupType, BackupFile, Position, FirstLSN, LastLSN)
			select b.BackupID, 'LOG', f.Path, b.Position, b.FirstLSN, b.LastLSN from #Backups b join #Files f on f.FileID = b.FileID where b.BackupID = @NextID;
		select @RequiredLSN = @NextLSN;
	end
	if exists(select * from #MediaPlan p join #Backups b on b.BackupID = p.BackupID where b.BackupType not in (1, 2, 5)
		or b.DatabaseName is null or b.FamilyGUID is null or b.BackupFinishDate is null or b.BackupSetGUID is null
		or b.FirstLSN is null or b.LastLSN is null or b.FirstLSN >= b.LastLSN or b.FirstFork is null or b.LastFork is null
		or isnull(b.IsDamaged, 1) <> 0 or isnull(b.IsSnapshot, 1) <> 0 or isnull(b.HasIncompleteMetaData, 1) <> 0 or b.FirstFork <> b.LastFork or b.ForkPointLSN is not null)
		throw 50000, 'A selected backup has incomplete, damaged, snapshot or unsupported recovery-fork metadata.', 1;
	-- Validate media labels only for the selected sequence, not every retained file.
	declare Media cursor local fast_forward for select BackupFile from #MediaPlan order by Ordinal;
	open Media;
	fetch next from Media into @Path;
	while @@fetch_status = 0
	begin
		truncate table #Label;
		select @Sql = N'restore labelonly from ' + @BackupDevice + N' = N''' + replace(@Path, N'''', N'''''') + N''';';
		insert #Label exec(@Sql);
		if (select count(*) from #Label) <> 1 or exists(select * from #Label where FamilyCount <> 1 or FamilyCount is null or FamilySequenceNumber <> 1)
			throw 50000, 'Selected striped or ambiguous media is not supported; provide complete single-file media.', 1;
		fetch next from Media into @Path;
	end
	close Media;
	deallocate Media;
	-- Accumulate file identities in native restore order; each new file belongs to its introducing command.
	create table #StepFiles
	(
		FileID bigint, LogicalName sysname, Type char(1), UniqueID uniqueidentifier,
		PhysicalName nvarchar(4000), CreateLSN numeric(25,0), DropLSN numeric(25,0), IsPresent bit
	);
	declare Logs cursor local fast_forward for
		select p.Ordinal, p.BackupType, p.BackupFile, p.Position, p.FirstLSN, p.LastLSN, b.DatabaseName from #MediaPlan p
			join #Backups b on b.BackupID = p.BackupID where p.BackupType in ('DIFF', 'LOG') order by p.Ordinal;
	open Logs;
	fetch next from Logs into @CurrentOrdinal, @StepType, @Path, @Position, @StepFirstLSN, @StepLastLSN, @StepSourceName;
	while @@fetch_status = 0
	begin
		exec z.usp_ReadBackupFileList @BackupFile = @Path, @Position = @Position, @FileListJson = @FileListJson output, @ReturnResult = 0;
		truncate table #StepFiles;
		insert #StepFiles (FileID, LogicalName, Type, UniqueID, PhysicalName, CreateLSN, DropLSN, IsPresent)
			select FileID, LogicalName, Type, UniqueID, PhysicalName, CreateLSN, DropLSN, IsPresent from z.fn_DecodeBackupFileList(@FileListJson);
		if exists(select * from #StepFiles where FileID is null or LogicalName is null or Type is null or Type not in ('D', 'L')
			or UniqueID is null or PhysicalName is null or (@StepType = 'DIFF' and IsPresent = 0) or DropLSN > 0)
			or exists(select * from #StepFiles group by FileID having count(*) > 1)
			or exists(select * from #StepFiles group by LogicalName having count(*) > 1)
			or exists(select * from #StepFiles group by UniqueID having count(*) > 1)
			throw 50000, 'A pending differential or log has incomplete, removed, reused or unsupported file metadata.', 1;
		if exists(select * from #StepFiles l join #FileMap m on m.FileID = l.FileID or m.LogicalName = l.LogicalName or m.UniqueID = l.UniqueID
			where m.FileID <> l.FileID or m.LogicalName <> l.LogicalName or m.UniqueID <> l.UniqueID or m.Type <> l.Type)
			throw 50000, 'A pending differential or log reuses or changes an existing file identity.', 1;
		if @StepType = 'DIFF' and exists(select * from #FileMap m where not exists
			(select * from #StepFiles l where l.FileID = m.FileID and l.UniqueID = m.UniqueID and l.LogicalName = m.LogicalName and l.Type = m.Type))
			throw 50000, 'The differential removes a mapped file; use an explicit restore sequence.', 1;
		if @StepType = 'LOG' and exists(select * from #StepFiles l where not exists(select * from #FileMap m where m.FileID = l.FileID)
			and (l.CreateLSN is null or l.CreateLSN < @StepFirstLSN or l.CreateLSN >= @StepLastLSN))
			throw 50000, 'A new log file must be created within that transaction-log backup interval to use MOVE.', 1;
		insert #FileMap (FileID, LogicalName, Type, UniqueID, OriginalPath, AddedOrdinal, SourceDatabaseName)
			select l.FileID, l.LogicalName, l.Type, l.UniqueID, l.PhysicalName, @CurrentOrdinal, @StepSourceName from #StepFiles l
				where not exists(select * from #FileMap m where m.FileID = l.FileID);
		fetch next from Logs into @CurrentOrdinal, @StepType, @Path, @Position, @StepFirstLSN, @StepLastLSN, @StepSourceName;
	end
	close Logs;
	deallocate Logs;
	if exists(select * from #FileMap where DestinationPath is null and SourceDatabaseName <> @TargetDatabaseName)
		and (@TargetDatabaseName like N'%[<>:"/\|?*]%' or right(@TargetDatabaseName, 1) in (N'.', N' '))
		throw 50000, 'The destination database name cannot be used safely in physical filenames.', 1;
	declare FileMap cursor local fast_forward for select FileID, LogicalName, Type, OriginalPath, SourceDatabaseName from #FileMap where DestinationPath is null order by AddedOrdinal, FileID;
	open FileMap;
	fetch next from FileMap into @FileID, @Logical, @Type, @Original, @FileSourceName;
	while @@fetch_status = 0
	begin
		select @Original = replace(@Original, N'\', N'/'), @Slash = charindex(N'/', reverse(replace(@Original, N'\', N'/')));
		select @Name = iif(@Slash = 0, @Original, right(@Original, @Slash - 1)),
			@Folder = iif(@Slash = 0, null, left(@Original, len(@Original) - @Slash + 1));
		if @IsLinux = 0 select @Folder = replace(@Folder, N'/', N'\');
		if @TargetDatabaseName <> @FileSourceName
			select @Name = iif(charindex(@FileSourceName, @Name) > 0, replace(@Name, @FileSourceName, @TargetDatabaseName), @TargetDatabaseName + N'_' + @Name);
		select @Destination = iif(@Type = 'L', @LogFolder, @DataFolder);
		if @Destination is null
			select @Destination = iif(@UseDefaultFolder = 1, iif(@Type = 'L', @DefaultLog, @DefaultData), @Folder);
		if nullif(trim(@Destination), N'') is null
			throw 50000, 'The selected original or instance-default destination directory is unavailable in metadata.', 1;
		if @Name is null or @Name = N'' or @Name in (N'.', N'..') throw 50000, 'A backup physical filename is invalid.', 1;
		select @Destination = @Destination + iif(right(@Destination, 1) in (N'/', N'\'), N'', @Separator) + @Name;
		if len(@Destination) > 260 throw 50000, 'A destination database-file path exceeds 260 characters.', 1;
		update #FileMap set DestinationPath = @Destination where FileID = @FileID;
		fetch next from FileMap into @FileID, @Logical, @Type, @Original, @FileSourceName;
	end
	close FileMap;
	deallocate FileMap;
	select @PrimaryPath = DestinationPath from #FileMap where FileID = 1;
	if exists(select * from #FileMap where DestinationPath is null) throw 50000, 'A destination file mapping is incomplete.', 1;
	if exists(select * from #FileMap group by case when @IsLinux = 1 then DestinationPath else lower(DestinationPath) end having count(*) > 1)
		throw 50000, 'Multiple files resolve to the same destination path.', 1;
	if exists(select * from #FileMap m join #Files f on
		(case when @IsLinux = 1 then m.DestinationPath else lower(m.DestinationPath) end) collate Latin1_General_100_BIN2 =
		(case when @IsLinux = 1 then f.Path else lower(replace(f.Path, N'/', N'\')) end) collate Latin1_General_100_BIN2)
		throw 50000, 'A destination database file collides with an input backup file.', 1;
	if exists(select * from #FileMap m join sys.master_files f on
		(case when @IsLinux = 1 then m.DestinationPath else lower(m.DestinationPath) end) collate Latin1_General_100_BIN2 =
		(case when @IsLinux = 1 then f.physical_name else lower(replace(f.physical_name, N'/', N'\')) end) collate Latin1_General_100_BIN2
		where @DatabaseID is null or f.database_id <> @DatabaseID)
		throw 50000, 'A destination file belongs to another database.', 1;
	if exists(select * from #FileMap m cross apply sys.dm_os_file_exists(m.DestinationPath) e where (@Continue = 0 or m.AddedOrdinal > 0) and (e.file_exists = 1 or e.file_is_a_directory = 1)
		and not exists(select * from sys.master_files f where f.database_id = @DatabaseID and (@Continue = 0 or (f.file_id = m.FileID and f.file_guid = m.UniqueID)) and
			(case when @IsLinux = 1 then f.physical_name else lower(replace(f.physical_name, N'/', N'\')) end) collate Latin1_General_100_BIN2 =
			(case when @IsLinux = 1 then m.DestinationPath else lower(m.DestinationPath) end) collate Latin1_General_100_BIN2))
		throw 50000, 'A destination path already exists outside the destination database; overwrite refused.', 1;

	if @RecoveryType = 'STANDBY'
	begin
		if @FullBackupPath is null throw 50000, 'The original full backup filename is unavailable; provide its backup folder for standby naming.', 1;
		if @Continue = 0 and exists(select * from #Backups where BackupID = @FullID and SoftwareVersionMajor <> convert(int, serverproperty('ProductMajorVersion')))
			throw 50000, 'STANDBY cannot be used when a database-version upgrade is required.', 1;
		select @Name = replace(@FullBackupPath, N'\', N'/'), @Original = replace(@PrimaryPath, N'\', N'/');
		if left(@Name, 7) collate Latin1_General_100_CI_AS = N'http://' or left(@Name, 8) collate Latin1_General_100_CI_AS = N'https://'
			or left(@Name, 5) collate Latin1_General_100_CI_AS = N's3://'
		begin
			select @Name = left(@Name, charindex(N'?', @Name + N'?') - 1);
			select @Name = left(@Name, charindex(N'#', @Name + N'#') - 1);
		end
		select @Slash = charindex(N'/', reverse(@Name));
		select @Name = iif(@Slash = 0, @Name, right(@Name, @Slash - 1));
		select @Dot = charindex(N'.', reverse(@Name));
		select @Name = iif(@Dot > 0, left(@Name, len(@Name) - @Dot), @Name) + N'.standby',
			@Folder = coalesce(@StandbyFolder, left(@Original, len(@Original) - charindex(N'/', reverse(@Original)) + 1));
		if @IsLinux = 0 select @Folder = replace(@Folder, N'/', N'\');
		if @Folder is null or not exists(select * from sys.dm_os_file_exists(@Folder) where file_is_a_directory = 1)
			throw 50000, 'The standby destination directory is unavailable.', 1;
		select @StandbyFile = @Folder + iif(right(@Folder, 1) in (N'/', N'\'), N'', @Separator) + @Name;
		if len(@StandbyFile) > 260 throw 50000, 'The standby path exceeds 260 characters.', 1;
		if exists(select * from sys.master_files where
			(case when @IsLinux = 1 then physical_name else lower(replace(physical_name, N'/', N'\')) end) collate Latin1_General_100_BIN2 =
			(case when @IsLinux = 1 then @StandbyFile else lower(@StandbyFile) end) collate Latin1_General_100_BIN2)
			or exists(select * from #FileMap where
				(case when @IsLinux = 1 then DestinationPath else lower(DestinationPath) end) collate Latin1_General_100_BIN2 =
				(case when @IsLinux = 1 then @StandbyFile else lower(@StandbyFile) end) collate Latin1_General_100_BIN2)
			or exists(select * from #Files where
				(case when @IsLinux = 1 then Path else lower(replace(Path, N'/', N'\')) end) collate Latin1_General_100_BIN2 =
				(case when @IsLinux = 1 then @StandbyFile else lower(@StandbyFile) end) collate Latin1_General_100_BIN2)
			throw 50000, 'The standby path collides with a database or backup file.', 1;
		if exists(select * from sys.dm_os_file_exists(@StandbyFile) where file_is_a_directory = 1 or file_exists = 1)
			and isnull(@IsStandby, 0) <> 1
			throw 50000, 'The standby output path already exists; overwrite refused.', 1;
	end
	select @FinalOption = case @RecoveryType when 'STANDBY' then N'standby = N''' + replace(@StandbyFile, N'''', N'''''') + N''''
		when 'RECOVERY' then N'recovery' else N'norecovery' end;
	select @RestoreCount = count(*) from #MediaPlan;
	update p set Command = N'restore ' + iif(p.BackupType in ('FULL', 'DIFF'), N'database ', N'log ') + quotename(@TargetDatabaseName)
		+ N' from ' + @BackupDevice + N' = N''' + replace(p.BackupFile, N'''', N'''''') + N'''' + @CrLf
		+ N'with ' + coalesce(a.Moves + N',' + @CrLf + nchar(9), N'') + N'file = ' + convert(nvarchar(11), p.Position) + iif(p.BackupType = 'FULL' and @DatabaseID is not null and @ReplaceExisting = 1, N', replace', N'')
		+ N', norecovery' + coalesce(N', ' + @OtherRestoreOptions, N'') + N';' from #MediaPlan p
		outer apply
		(
			select string_agg(convert(nvarchar(max), N'move N''' + replace(m.LogicalName collate database_default, N'''', N'''''')
				+ N''' to N''' + replace(m.DestinationPath collate database_default, N'''', N'''''') + N''''), @MoveSeparator) within group (order by m.FileID) Moves
			from #FileMap m where m.AddedOrdinal = p.Ordinal
		) a;
	if @RecoveryType <> 'NORECOVERY' and not (@RestoreCount = 0 and isnull(@IsStandby, 0) = 1 and @RecoveryType = 'STANDBY')
		insert #MediaPlan (BackupType, Command) values ('FINALIZE', N'restore database ' + quotename(@TargetDatabaseName) + N' with ' + @FinalOption + N';');
	-- Only an ONLINE destination can admit user connections. RESTORING and other unavailable states need no access change.
	if @DropConnections = 1 and @DatabaseID is not null and @InitialState = 0 and exists(select * from #MediaPlan)
	begin
		select @SingleUserSql = N'alter database ' + quotename(@TargetDatabaseName) + N' set single_user with rollback immediate;';
		select @RestoreAccessSql = N'alter database ' + quotename(@TargetDatabaseName) + N' set '
			+ case @InitialUserAccess when 0 then N'multi_user' when 1 then N'single_user' when 2 then N'restricted_user' end + N';';
	end
	create table #RestoreExecutionState
	(
		StateID tinyint not null primary key check (StateID = 1),
		AccessChanged bit not null,
		AccessCreateDate datetime
	);
	insert #RestoreExecutionState (StateID, AccessChanged, AccessCreateDate) values (1, 0, @InitialCreateDate);
	create table #Plan
	(
		Ordinal int not null primary key,
		DatabaseName sysname not null,
		IsContinuation bit not null,
		BackupType varchar(10) not null,
		BackupFile nvarchar(4000),
		Position int,
		FirstLSN numeric(25,0),
		LastLSN numeric(25,0),
		Command nvarchar(max) not null
	);
	insert #Plan (Ordinal, DatabaseName, IsContinuation, BackupType, BackupFile, Position, FirstLSN, LastLSN, Command)
		select Ordinal, @TargetDatabaseName, @Continue, BackupType, BackupFile, Position, FirstLSN, LastLSN, Command from #MediaPlan;
	if @SingleUserSql is not null
	begin
		insert #Plan (Ordinal, DatabaseName, IsContinuation, BackupType, Command)
			values (0, @TargetDatabaseName, @Continue, 'SINGLEUSER', @SingleUserSql);
		select @RestoreAccessSql = N'if exists(select * from #RestoreExecutionState s join sys.databases d on d.database_id = '
			+ convert(nvarchar(11), @InitialDatabaseID) + N' where s.StateID = 1 and s.AccessChanged = 1 and d.name = N'''
			+ replace(@TargetDatabaseName, N'''', N'''''') + N''' and d.create_date = s.AccessCreateDate and d.state = 0)'
			+ @CrLf + N'begin' + @CrLf + nchar(9) + @RestoreAccessSql
			+ @CrLf + nchar(9) + N'update #RestoreExecutionState set AccessChanged = 0 where StateID = 1;'
			+ @CrLf + N'end;';
		insert #Plan (Ordinal, DatabaseName, IsContinuation, BackupType, Command)
			select max(Ordinal) + 1, @TargetDatabaseName, @Continue, 'ACCESSMODE', @RestoreAccessSql from #Plan;
	end
	if @ShowPlan = 1
	begin
		select * from #Plan order by Ordinal;
		select FileID, LogicalName, Type, OriginalPath, DestinationPath, @StandbyFile StandbyFile, AddedOrdinal from #FileMap order by AddedOrdinal, FileID;
		select @SourceName SourceDatabaseName, @Family SourceFamilyGUID, iif(@FastNames = 1, 'FILENAME', 'HEADER') DiscoveryMode,
			(select count(*) from #Files) FilesDiscovered, @ReadCount HeadersRead;
		return;
	end

	-- Recheck the destination after metadata inspection; native RESTORE also checks the media and restore state.
	if isnull(db_id(@TargetDatabaseName), -1) <> isnull(@InitialDatabaseID, -1)
		or exists(select * from sys.databases where database_id = @InitialDatabaseID and (state <> @InitialState or is_in_standby <> @InitialStandby or create_date <> @InitialCreateDate))
		throw 50000, 'The destination changed while the restore plan was being built; run the procedure again.', 1;
	begin try
		declare RestoreCommands cursor local fast_forward for select Ordinal, BackupType, Command from #Plan order by Ordinal;
		open RestoreCommands;
		fetch next from RestoreCommands into @CurrentOrdinal, @StepType, @Sql;
		while @@fetch_status = 0
		begin
			-- A preceding restore consumes the prior undo file; never overwrite an unrelated output file.
			if @RecoveryType = 'STANDBY' and @StepType = 'FINALIZE'
				and exists(select * from sys.dm_os_file_exists(@StandbyFile) where file_exists = 1 or file_is_a_directory = 1)
				throw 50000, 'The standby output path still exists after consuming prior undo; overwrite refused.', 1;
			exec z.usp_PrintString @Sql;
			exec(@Sql);
			if @StepType = 'SINGLEUSER' select @AccessChanged = 1, @AccessCreateDate = @InitialCreateDate;
			-- A successful restore may update creation metadata. Rebind cleanup only to the planned family and every mapped file.
			if @StepType in ('FULL', 'DIFF', 'LOG', 'FINALIZE') and @AccessChanged = 1 and not exists(select * from #FileMap m where m.AddedOrdinal <= @CurrentOrdinal and not exists
				(select * from sys.master_files f where f.database_id = @InitialDatabaseID and f.file_id = m.FileID and f.file_guid = m.UniqueID
					and (case when @IsLinux = 1 then f.physical_name else lower(replace(f.physical_name, N'/', N'\')) end) collate Latin1_General_100_BIN2 =
					(case when @IsLinux = 1 then m.DestinationPath else lower(m.DestinationPath) end) collate Latin1_General_100_BIN2))
				and not exists(select * from sys.master_files f where f.database_id = @InitialDatabaseID and not exists(select * from #FileMap m where m.FileID = f.file_id and m.AddedOrdinal <= @CurrentOrdinal))
				select @AccessCreateDate = d.create_date from sys.databases d join sys.database_recovery_status r on r.database_id = d.database_id
				where d.database_id = @InitialDatabaseID and d.name = @TargetDatabaseName and d.state = 0 and r.family_guid = @Family;
			if @StepType = 'ACCESSMODE'
				select @AccessChanged = AccessChanged from #RestoreExecutionState where StateID = 1;
			else update #RestoreExecutionState set AccessChanged = @AccessChanged, AccessCreateDate = @AccessCreateDate where StateID = 1;
			fetch next from RestoreCommands into @CurrentOrdinal, @StepType, @Sql;
		end
		close RestoreCommands;
		deallocate RestoreCommands;
	end try
	begin catch
		-- Reuse the same guarded cleanup query while preserving the original restore error.
		select @Sql = null;
		select @Sql = Command from #Plan where BackupType = 'ACCESSMODE';
		if @AccessChanged = 1 and @Sql is not null
		begin
			exec z.usp_PrintString @Sql;
			begin try
				exec(@Sql);
			end try
			begin catch
				select @Sql = N'Could not restore the destination access mode: ' + error_message();
				exec z.usp_PrintString @Sql;
			end catch
		end;
		throw;
	end catch
end
