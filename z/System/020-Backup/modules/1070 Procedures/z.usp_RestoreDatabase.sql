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
	@OtherRestoreOptions nvarchar(max) = N'stats = 10',
	@DataFolder nvarchar(4000) = null,
	@LogFolder nvarchar(4000) = null,
	@StandbyFolder nvarchar(4000) = null,
	@UseDefaultFolder bit = 1,
	@ShowPlan bit = 0,
	@DropConnections bit = 1
)
as
begin
	set nocount,xact_abort on;
	if @@trancount <> 0
	begin
		set xact_abort off;
		throw 50000, 'RestoreDatabase cannot run inside a user transaction.', 1;
	end

	if @ReplaceExisting is null or @ShowPlan is null or @UseDefaultFolder is null or @DropConnections is null
		throw 50000, 'ReplaceExisting, ShowPlan, UseDefaultFolder and DropConnections must not be null.', 1;

	select	@BackupPath = nullif(trim(@BackupPath), N''), @TargetDatabaseName = nullif(trim(@TargetDatabaseName), N''), @RecoveryType = upper(trim(@RecoveryType)),
			@DataFolder = nullif(trim(@DataFolder), N''), @LogFolder = nullif(trim(@LogFolder), N''), @StandbyFolder = nullif(trim(@StandbyFolder), N'');

	if @BackupPath is null
		throw 50000, 'BackupPath is required.', 1;

	if @RecoveryType is null or @RecoveryType not in ('NORECOVERY', 'RECOVERY', 'STANDBY')
		throw 50000, 'RecoveryType must be NORECOVERY, RECOVERY or STANDBY.', 1;

	declare	@IsLinux bit = z.fn_IsLinux(), @Separator nchar(1), @IsFolder bit = 0, @FileExists bit,
			@Path nvarchar(4000), @Folder nvarchar(4000),
			@IsUrl bit,	@BackupDevice nvarchar(4), @CrLf nvarchar(2) = nchar(13) + nchar(10), @MoveSeparator nvarchar(4) = N',' + nchar(13) + nchar(10) + nchar(9),
			@FileID int, @BackupID int, @FullID int, @Position int, @HeaderJson nvarchar(max), @FileListJson nvarchar(max), @Sql nvarchar(max),
			@SourceName sysname, @Family uniqueidentifier, @Fork uniqueidentifier, @RequiredLSN numeric(25,0),
			@NextLSN numeric(25,0), @NextID int, @DatabaseID int, @State tinyint, @IsStandby bit, @Continue bit = 0, @ForceFullRestore bit = 0,
			@NativeFamily uniqueidentifier, @NativeFork uniqueidentifier, @HistoryFamily uniqueidentifier, @HistoryFork uniqueidentifier,
			@HistoryLSN numeric(25,0), @HistoryID int, @FullBackupPath nvarchar(4000), @PrimaryPath nvarchar(4000),
			@DefaultData nvarchar(4000) = convert(nvarchar(4000), serverproperty('InstanceDefaultDataPath')),
			@DefaultLog nvarchar(4000) = convert(nvarchar(4000), serverproperty('InstanceDefaultLogPath')),
			@Name nvarchar(4000), @Original nvarchar(4000), @Destination nvarchar(4000), @Logical sysname, @Type char(1),
			@Slash int, @FinalOption nvarchar(max), @StandbyFile nvarchar(4000),
			@RestoreCount int, @InitialDatabaseID int, @InitialState tinyint, @InitialStandby bit, @InitialCreateDate datetime,
			@SingleUserSql nvarchar(max), @RestoreAccessSql nvarchar(max), @AccessChanged bit = 0, @InitialUserAccess tinyint, @AccessCreateDate datetime,
			@HasRecognizedBackupFileNames bit, @RequestedName sysname = @TargetDatabaseName, @InferredFamily uniqueidentifier, @Prefix nvarchar(4000), @RequestedPrefix nvarchar(4000),
			@DiffID int, @BaseGUID uniqueidentifier, @BaseLSN numeric(25,0), @BaseCopyOnly bit, @HistoryType char(1),
			@CurrentOrdinal int, @StepType varchar(10), @StepSourceName sysname, @FileSourceName sysname, @StepFirstLSN numeric(25,0), @StepLastLSN numeric(25,0),
			@Stage tinyint, @ReadCount int = 0, @FileMapCreated bit = 0, @ScanLSN numeric(25,0), @ScanEnd numeric(25,0), @CandidateType smallint;
	if nullif(trim(translate(@OtherRestoreOptions, nchar(9) + nchar(10) + nchar(11) + nchar(12) + nchar(13), N'     ')), N'') is null
		select	@OtherRestoreOptions = null;
	select	@Separator = iif(@IsLinux = 1, N'/', N'\'),
			@IsUrl = iif(
								left(@BackupPath, 7) collate Latin1_General_100_CI_AS = N'http://'
							or left(@BackupPath, 8) collate Latin1_General_100_CI_AS = N'https://'
							or left(@BackupPath, 5) collate Latin1_General_100_CI_AS = N's3://',
						1, 0);
	select @BackupDevice = iif(@IsUrl = 1, N'url', N'disk');
	if @IsLinux = 0
	begin
		if @IsUrl = 0
			select @BackupPath = replace(@BackupPath, N'/', N'\');
		select	@DataFolder = replace(@DataFolder, N'/', N'\'),
				@LogFolder = replace(@LogFolder, N'/', N'\'),
				@StandbyFolder = replace(@StandbyFolder, N'/', N'\');
	end
	if @RecoveryType = 'STANDBY' and @StandbyFolder is not null and not exists(select * from sys.dm_os_file_exists(@StandbyFolder) where file_is_a_directory = 1)
		throw 50000, 'The explicit StandbyFolder does not exist or is inaccessible.', 1;
	-- Remote paths identify exactly one object; only local paths can be tested or enumerated as folders.
	if @IsUrl = 0
	begin
		select @IsFolder = file_is_a_directory, @FileExists = file_exists from sys.dm_os_file_exists(@BackupPath);
		if @IsFolder is null
			throw 50000, 'BackupPath is inaccessible.', 1;
		if @IsFolder = 0 and @FileExists = 0
			throw 50000, 'BackupPath does not identify an accessible file or folder.', 1;
	end

	create table #Files
	(
		FileID int identity(1,1) not null primary key, Path nvarchar(4000) collate Latin1_General_100_BIN2 not null,
		FileName nvarchar(4000),
		FileNameWithoutExtension as (left(FileName, len(FileName) - charindex(N'.', reverse(FileName)))),
		Prefix nvarchar(4000), DatabaseName nvarchar(128), Stamp datetime2(7), Kind smallint,
		Inspected bit not null default 0, ReadError nvarchar(2048)
	);
	if @IsFolder = 1
	begin
		insert #Files (Path)
			select distinct e.full_filesystem_path
			from sys.dm_os_enumerate_filesystem(@BackupPath, N'*') e
			where e.is_directory = 0;
	end
	else
	begin
		insert #Files (Path)
			values (@BackupPath);
	end
	if not exists(select * from #Files)
		throw 50000, 'No backup files were found.', 1;

	create table #Label
	(
		MediaName nvarchar(128), MediaSetId uniqueidentifier, FamilyCount int, FamilySequenceNumber int,
		MediaFamilyId uniqueidentifier, MediaSequenceNumber int, MediaLabelPresent tinyint, MediaDescription nvarchar(255),
		SoftwareName nvarchar(128), SoftwareVendorId int, MediaDate datetime, Mirror_Count int, IsCompressed bit
	);
	create table #Backups
	(
		BackupID int identity(1,1) not null, FileID int not null, Position int not null, BackupType smallint not null, DatabaseName sysname,
		FamilyGUID uniqueidentifier, FirstFork uniqueidentifier, LastFork uniqueidentifier, ForkPointLSN numeric(25,0), FirstLSN numeric(25,0),
		LastLSN numeric(25,0), BackupFinishDate datetime, BackupSetGUID uniqueidentifier, SoftwareVersionMajor int, IsDamaged bit,
		IsSnapshot bit, HasIncompleteMetaData bit, CheckpointLSN numeric(25,0), DifferentialBaseLSN numeric(25,0), DifferentialBaseGUID uniqueidentifier, IsCopyOnly bit,
		primary key(FileID, BackupID)
	);
	-- Names emitted by usp_BackupDatabase allow candidate ordering without opening old media.
	update #Files set FileName = right(replace(Path, N'\', N'/'), charindex(N'/', reverse(replace(Path, N'\', N'/')) + N'/') - 1);
	update f
		set Prefix = n.Prefix, DatabaseName = n.DatabaseName, Stamp = n.BackupTime, Kind = n.BackupType
	from #Files f
		cross apply z.fn_DecodeBackupFileName(f.FileName) n;
	-- Different database hints can represent a source rename; server/instance prefixes and filename formats do not change the source.
	select	@HasRecognizedBackupFileNames = iif(
													@IsFolder = 1 and not exists(select * from #Files where Kind is null)
													and (select count(distinct DatabaseName) from #Files) = 1
												, 1, 0),
			@RequestedPrefix = z.fn_StandardizeFileName(@RequestedName),
			@DatabaseID = db_id(@TargetDatabaseName);
___DiscoverSoure___:
	-- A misleading managed name restarts planning from the cached headers, without re-reading them.
	if @FileMapCreated = 1
	begin
		drop table #FileMap;
		select @FileMapCreated = 0;
	end

	select	@TargetDatabaseName = @RequestedName, @DatabaseID = db_id(@RequestedName), @State = null, @IsStandby = null,
			@SourceName = null, @Family = null, @FullID = null, @DiffID = null, @FullBackupPath = null, @ForceFullRestore = 0,
			@BaseGUID = null, @BaseLSN = null, @BaseCopyOnly = null, @HistoryType = null, @HistoryID = null, @HistoryLSN = null,
			@HistoryFamily = null, @HistoryFork = null, @NativeFamily = null, @NativeFork = null, @RequiredLSN = null, @Fork = null;

	select	@State = state, @IsStandby = is_in_standby
	from sys.databases
	where database_id = @DatabaseID;
	select	@Continue = iif(@State = 1 or @IsStandby = 1, 1, 0);
	if @Continue = 1
	begin
		select @Family = family_guid, @NativeFamily = family_guid, @NativeFork = recovery_fork_guid
		from sys.database_recovery_status
		where database_id = @DatabaseID;
		if @InferredFamily is not null and @NativeFamily is not null and @NativeFamily <> @InferredFamily
			throw 50000, 'The existing destination belongs to a different family than the backup used to infer its name.', 1;
		select top (1)
				@RequiredLSN = min(redo_start_lsn) over (),
				@Fork = redo_start_fork_guid
		from sys.master_files
		where database_id = @DatabaseID
			and type = 0
			and redo_start_lsn is not null
		order by file_id;
		if @Family is null or @NativeFork is null
		begin
			select @Continue = 0, @ForceFullRestore = 1;
		end
	end

	-- Replacement starts with full candidates; continuation identifies its source from logs or differentials.
	while 1 = 1
	begin
		if @Continue = 1
			select top (1) @SourceName = DatabaseName from #Backups where FamilyGUID = @Family
				order by BackupFinishDate desc, Position desc;
		select @FileID = null;
		if @HasRecognizedBackupFileNames = 0
		begin
			select top (1) @FileID = FileID, @Path = Path
			from #Files
			where Inspected = 0
			order by FileNameWithoutExtension desc, FileID;
		end
		else if @RequestedName is null
		begin
			select top (1) @FileID = FileID, @Path = Path
			from #Files
			where Inspected = 0 and Kind in (1, 2)
			order by iif(Kind = 2, 0, 1), Stamp desc, FileNameWithoutExtension desc, FileID;
		end
		else if @Continue = 0 and @FullID is null and not exists(select * from #Backups where BackupType = 1 and ((@InferredFamily is null and DatabaseName = @RequestedName) or FamilyGUID = @InferredFamily))
		begin
			select top (1) @FileID = FileID, @Path = Path
			from #Files
			where Inspected = 0 and Kind = 1
			order by iif(DatabaseName = @RequestedPrefix, 0, 1), Stamp desc, FileNameWithoutExtension desc, FileID;
		end
		else if @Continue = 1 and @SourceName is null
		begin
			select top (1) @FileID = FileID, @Path = Path
			from #Files
			where Inspected = 0 and Kind in (2, 5)
			order by iif(Kind = 2, 0, 1), Stamp desc, FileNameWithoutExtension desc, FileID;
		end
		if @FileID is null
			break;
		update #Files set Inspected = 1 where FileID = @FileID;
		begin try
			select @ReadCount += 1;
			exec z.usp_ReadBackupHeader @BackupFile = @Path, @HeaderJson = @HeaderJson output, @ReturnResult = 0;
			insert #Backups (
								FileID, Position, BackupType, DatabaseName, FamilyGUID,
								FirstFork, LastFork, ForkPointLSN, FirstLSN, LastLSN,
								BackupFinishDate, BackupSetGUID, SoftwareVersionMajor, IsDamaged, IsSnapshot,
								HasIncompleteMetaData, CheckpointLSN, DifferentialBaseLSN, DifferentialBaseGUID, IsCopyOnly
							)
				select	@FileID, Position, BackupType, DatabaseName, FamilyGUID,
						FirstRecoveryForkID, RecoveryForkID, ForkPointLSN, FirstLSN, LastLSN,
						BackupFinishDate, BackupSetGUID, SoftwareVersionMajor, IsDamaged, IsSnapshot,
						HasIncompleteMetaData, CheckpointLSN, DifferentialBaseLSN, DifferentialBaseGUID, IsCopyOnly
				from z.fn_DecodeBackupHeader(@HeaderJson);
		end try
		begin catch
			update #Files set ReadError = error_message() where FileID = @FileID;
		end catch
		if @Continue = 1
		begin
			select top (1) @SourceName = DatabaseName
			from #Backups
			where FamilyGUID = @Family
			order by BackupFinishDate desc, Position desc;
		end
		if @HasRecognizedBackupFileNames = 1
		begin
			if exists(
						select *
						from #Backups b
							inner join #Files f on f.FileID = b.FileID
						where b.FileID = @FileID
						and (
									b.BackupType <> f.Kind
								or	b.DatabaseName is null
								or	f.DatabaseName = @RequestedPrefix and b.DatabaseName <> @RequestedName
								or z.fn_StandardizeFileName(b.DatabaseName) <> f.DatabaseName
							)
					)
			begin
				select @HasRecognizedBackupFileNames = 0;
			end
			else if @Continue = 0
			begin
				select @FullID = BackupID
				from #Backups
				where FileID = @FileID
					and BackupType = 1 and (@InferredFamily is null or FamilyGUID = @InferredFamily);
			end
			if @Continue = 1 and @SourceName is not null break;
		end
		if @RequestedName is null and @HasRecognizedBackupFileNames = 1
		begin
			select top (1) @RequestedName = DatabaseName, @InferredFamily = FamilyGUID
			from #Backups
			where FileID = @FileID and BackupType in (1, 2) and DatabaseName is not null and FamilyGUID is not null
			order by iif(BackupType = 2, 0, 1), BackupFinishDate desc, Position desc;
			if @RequestedName is not null
			begin
				select @RequestedPrefix = z.fn_StandardizeFileName(@RequestedName);
				goto ___DiscoverSoure___;
			end
		end
	end
	if @RequestedName is null
	begin
		select top (1) @RequestedName = DatabaseName, @InferredFamily = FamilyGUID
		from #Backups
		where BackupType in (1, 2) and DatabaseName is not null and FamilyGUID is not null
		order by iif(BackupType = 2, 0, 1), BackupFinishDate desc, LastLSN desc, Position desc;
		if @RequestedName is not null
		begin
			select @RequestedPrefix = z.fn_StandardizeFileName(@RequestedName);
			goto ___DiscoverSoure___;
		end
	end
	if @Continue = 1
		select top (1) @SourceName = DatabaseName from #Backups where FamilyGUID = @Family
			order by BackupFinishDate desc, Position desc;
	if @Continue = 0
	begin
		select @FullID = null;
		select top (1) @FullID = b.BackupID, @FullBackupPath = f.Path, @SourceName = b.DatabaseName, @Family = b.FamilyGUID
			from #Backups b join #Files f on f.FileID = b.FileID where b.BackupType = 1
				and (@InferredFamily is null or b.FamilyGUID = @InferredFamily)
			order by iif(b.DatabaseName = @RequestedName, 0, 1), b.BackupFinishDate desc, b.LastLSN desc, f.Path, b.Position desc;
		if @FullID is null and @InferredFamily is not null
			throw 50000, 'A full backup matching the inferred database family is required to initialize or replace the destination.', 1;
		if @FullID is null and @IsFolder = 0
			select top (1) @SourceName = DatabaseName, @Family = FamilyGUID from #Backups order by BackupID;
	end
	if @Family is null or (@SourceName is null and not (@Continue = 1 and @IsFolder = 1 and @HasRecognizedBackupFileNames = 1
		and not exists(select * from #Files where Kind in (2, 5))))
		throw 50000, 'No readable backup source identity could be selected.', 1;
	if @TargetDatabaseName is null and @FullID is null throw 50000, 'TargetDatabaseName is required when providing a log or differential file.', 1;
	select @TargetDatabaseName = coalesce(@TargetDatabaseName, @SourceName), @DatabaseID = db_id(coalesce(@TargetDatabaseName, @SourceName));
	if @TargetDatabaseName in (N'master', N'model', N'msdb', N'tempdb') or @DatabaseID <= 4 or @TargetDatabaseName = db_name()
		throw 50000, 'System databases and the database hosting this procedure cannot be restore targets.', 1;
	if exists(select * from sys.databases where database_id = @DatabaseID and (source_database_id is not null or group_database_id is not null))
		throw 50000, 'Database snapshots and availability-group databases are not supported restore targets.', 1;
	select @State = state, @IsStandby = is_in_standby from sys.databases where database_id = @DatabaseID;
	select @InitialDatabaseID = @DatabaseID, @InitialState = @State, @InitialStandby = @IsStandby,
		@Continue = iif(@ForceFullRestore = 0 and (@State = 1 or @IsStandby = 1), 1, 0);
	select @InitialCreateDate = create_date, @InitialUserAccess = user_access from sys.databases where database_id = @DatabaseID;
	if @Continue = 1 and @NativeFamily is null
	begin
		select @NativeFamily = family_guid, @NativeFork = recovery_fork_guid from sys.database_recovery_status where database_id = @DatabaseID;
		if @InferredFamily is not null and @NativeFamily is not null and @NativeFamily <> @InferredFamily
			throw 50000, 'The existing destination belongs to a different family than the backup used to infer its name.', 1;
		if @NativeFamily is null or @NativeFork is null
		begin
			if @ReplaceExisting = 0 throw 50000, 'Destination recovery identity is unavailable and ReplaceExisting is disabled.', 1;
			select @Continue = 0, @ForceFullRestore = 1;
		end
	end
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
		SourceDatabaseName sysname null
	);
	select @FileMapCreated = 1;
	if @Continue = 1
	begin
		select @FullBackupPath = null;
		select @PrimaryPath = physical_name from sys.master_files where database_id = @DatabaseID and file_id = 1;
		select @NativeFamily = family_guid, @NativeFork = recovery_fork_guid from sys.database_recovery_status where database_id = @DatabaseID;
		if @NativeFamily is null or @NativeFamily <> @Family throw 50000, 'Destination backup family does not match the source.', 1;
		select @RequiredLSN = min(redo_start_lsn) from sys.master_files where database_id = @DatabaseID and type = 0;
		select top (1) @Fork = redo_start_fork_guid from sys.master_files where database_id = @DatabaseID and type = 0 and redo_start_lsn is not null order by file_id;
		if exists(select * from sys.master_files where database_id = @DatabaseID and type = 0 and redo_start_lsn is not null
			and (redo_start_fork_guid is null or redo_start_fork_guid <> @Fork))
			throw 50000, 'The destination has inconsistent file recovery forks.', 1;

		-- Inspect the newest relevant differential before asking history whether it can be applied.
		while @HasRecognizedBackupFileNames = 1 and @RequiredLSN is not null and @Fork is not null and @SourceName is not null
			and not exists
			(
				select * from #Backups b
					left join sys.master_files f on f.database_id = @DatabaseID and f.file_id = 1
				where b.BackupType = 5 and b.FamilyGUID = @Family and b.FirstFork = @Fork and b.LastFork = @Fork
					and (b.LastLSN <= @RequiredLSN or (b.LastLSN > @RequiredLSN and
						(f.differential_base_guid is null or f.differential_base_lsn is null
							or (b.DifferentialBaseGUID = f.differential_base_guid and b.DifferentialBaseLSN = f.differential_base_lsn))))
			)
		begin
			select @FileID = null;
			select top (1) @FileID = FileID, @Path = Path
			from #Files
			where Inspected = 0 and Kind = 5 and DatabaseName = z.fn_StandardizeFileName(@SourceName)
			order by Stamp desc, FileNameWithoutExtension desc, FileID;
			if @FileID is null break;
			update #Files set Inspected = 1 where FileID = @FileID;
			begin try
				select @ReadCount += 1;
				exec z.usp_ReadBackupHeader @BackupFile = @Path, @HeaderJson = @HeaderJson output, @ReturnResult = 0;
				insert #Backups (FileID, Position, BackupType, DatabaseName, FamilyGUID, FirstFork, LastFork, ForkPointLSN, FirstLSN, LastLSN,
					BackupFinishDate, BackupSetGUID, SoftwareVersionMajor, IsDamaged, IsSnapshot, HasIncompleteMetaData, CheckpointLSN, DifferentialBaseLSN, DifferentialBaseGUID, IsCopyOnly)
					select @FileID, Position, BackupType, DatabaseName, FamilyGUID, FirstRecoveryForkID, RecoveryForkID, ForkPointLSN, FirstLSN, LastLSN,
						BackupFinishDate, BackupSetGUID, SoftwareVersionMajor, IsDamaged, IsSnapshot, HasIncompleteMetaData, CheckpointLSN, DifferentialBaseLSN, DifferentialBaseGUID, IsCopyOnly
						from z.fn_DecodeBackupHeader(@HeaderJson);
			end try
			begin catch
				update #Files set ReadError = error_message() where FileID = @FileID;
			end catch
			if exists(select * from #Backups b join #Files f on f.FileID = b.FileID where b.FileID = @FileID
				and (b.BackupType <> f.Kind or b.DatabaseName is null or z.fn_StandardizeFileName(b.DatabaseName) <> f.DatabaseName))
			begin
				select @HasRecognizedBackupFileNames = 0;
				goto ___DiscoverSoure___;
			end
		end

		-- A matching full header and current redo position can prove differential eligibility without history.
		select top (1) @BaseGUID = b.BackupSetGUID, @BaseLSN = b.CheckpointLSN, @BaseCopyOnly = b.IsCopyOnly
		from #Backups b join sys.master_files f on f.database_id = @DatabaseID and f.file_id = 1
		where b.BackupType = 1 and b.FamilyGUID = @Family and b.LastFork = @Fork and b.FirstFork = @Fork
			and b.LastLSN = @RequiredLSN and b.BackupSetGUID = f.differential_base_guid and b.CheckpointLSN = f.differential_base_lsn
		order by b.BackupFinishDate desc, b.Position desc;

		-- Only absent native progress or an unproven differential base needs the latest restore record.
		if @RequiredLSN is null or @Fork is null or (@BaseGUID is null and exists
		(
			select * from #Backups b
				left join sys.master_files f on f.database_id = @DatabaseID and f.file_id = 1
			where b.BackupType = 5 and b.FamilyGUID = @Family and b.FirstFork = @Fork and b.LastFork = @Fork and b.LastLSN > @RequiredLSN
				and (f.differential_base_guid is null or f.differential_base_lsn is null
					or (b.DifferentialBaseGUID = f.differential_base_guid and b.DifferentialBaseLSN = f.differential_base_lsn))
		))
		begin
			select top (1) @HistoryID = r.restore_history_id, @HistoryFamily = b.family_guid, @HistoryFork = b.last_recovery_fork_guid,
				@HistoryLSN = b.last_lsn, @HistoryType = b.type,
				@BaseGUID = iif(b.type = 'D', b.backup_set_uuid, null), @BaseLSN = iif(b.type = 'D', b.checkpoint_lsn, null),
				@BaseCopyOnly = iif(b.type = 'D', b.is_copy_only, null)
			from msdb.dbo.restorehistory r join msdb.dbo.backupset b on b.backup_set_id = r.backup_set_id
			where r.destination_database_name = @TargetDatabaseName
			order by r.restore_history_id desc;
			if @HistoryID is null or @HistoryFamily is null or @HistoryFamily <> @Family or @HistoryFork is null or @HistoryFork <> @NativeFork
				or exists(select * from msdb.dbo.restorehistory where restore_history_id = @HistoryID and
					(restore_type is null or restore_type not in ('D', 'I', 'L') or recovery is null or recovery <> 0 or stop_at is not null or stop_at_mark_name is not null or stop_before = 1
						or restore_date is null or (@HistoryType <> 'D' and restore_date < @InitialCreateDate)))
			begin
				if @RequiredLSN is null or @Fork is null
					throw 50000, 'Native metadata is insufficient and compatible unrecovered restore history is unavailable.', 1;
				select @BaseGUID = null, @BaseLSN = null, @BaseCopyOnly = null;
			end
			if @RequiredLSN is null or @Fork is null
			begin
				if @IsStandby <> 1 throw 50000, 'Destination native redo position is unavailable.', 1;
				select @RequiredLSN = @HistoryLSN, @Fork = @NativeFork;
			end
			-- History must not claim a full base at a different current native restore position.
			if @HistoryLSN <> @RequiredLSN select @BaseGUID = null, @BaseLSN = null, @BaseCopyOnly = null;
		end
		if @RequiredLSN is null or @Fork is null or @NativeFork is null or @Fork <> @NativeFork
			throw 50000, 'Destination redo position or recovery fork is unavailable or inconsistent.', 1;
		-- Native redo metadata is authoritative while RESTORING; history must never advance it.
		insert #FileMap (FileID, LogicalName, Type, UniqueID, OriginalPath, DestinationPath, SourceDatabaseName)
			select file_id, name, iif(type = 1, 'L', 'D'), file_guid, physical_name, physical_name, @SourceName from sys.master_files
			where database_id = @DatabaseID and type in (0, 1);
		if exists(select * from sys.master_files where database_id = @DatabaseID and type not in (0, 1))
			throw 50000, 'Only ROWS and LOG layouts support continuation through this procedure.', 1;
		-- Supplied folders govern new files only; current physical paths remain unchanged.

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
	select @Prefix = z.fn_StandardizeFileName(@SourceName), @Stage = 5;
	while @Stage in (5, 2)
	begin
		while 1 = 1
		begin
			if @HasRecognizedBackupFileNames = 1 and @Stage = 5 and @BaseCopyOnly = 0 and exists
			(
				select * from #Backups where BackupType = 5 and FamilyGUID = @Family and FirstFork = @Fork and LastFork = @Fork
					and DifferentialBaseGUID = @BaseGUID and DifferentialBaseLSN = @BaseLSN and LastLSN > @RequiredLSN
			) break;
			if @HasRecognizedBackupFileNames = 1 and @Stage = 2 and exists(select * from #Backups where BackupType = 2 and FamilyGUID = @Family and FirstFork = @Fork and LastFork = @Fork)
			begin
				-- Reuse cached headers before opening another file; stop when they cover the required LSN through the newest log.
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
			select @FileID = null;
			if @HasRecognizedBackupFileNames = 0
				select top (1) @FileID = FileID, @Path = Path from #Files where Inspected = 0 order by FileNameWithoutExtension desc, FileID;
			else if @Stage = 2 or (@BaseGUID is not null and @BaseCopyOnly = 0)
				select top (1) @FileID = FileID, @Path = Path from #Files
					where Inspected = 0 and Kind = @Stage and DatabaseName = @Prefix order by Stamp desc, FileNameWithoutExtension desc, FileID;
			if @FileID is null break;
			update #Files set Inspected = 1 where FileID = @FileID;
			begin try
				select @ReadCount += 1;
				exec z.usp_ReadBackupHeader @BackupFile = @Path, @HeaderJson = @HeaderJson output, @ReturnResult = 0;
				insert #Backups (FileID, Position, BackupType, DatabaseName, FamilyGUID, FirstFork, LastFork, ForkPointLSN, FirstLSN, LastLSN,
					BackupFinishDate, BackupSetGUID, SoftwareVersionMajor, IsDamaged, IsSnapshot, HasIncompleteMetaData, CheckpointLSN, DifferentialBaseLSN, DifferentialBaseGUID, IsCopyOnly)
					select @FileID, Position, BackupType, DatabaseName, FamilyGUID, FirstRecoveryForkID, RecoveryForkID, ForkPointLSN, FirstLSN, LastLSN,
						BackupFinishDate, BackupSetGUID, SoftwareVersionMajor, IsDamaged, IsSnapshot, HasIncompleteMetaData, CheckpointLSN, DifferentialBaseLSN, DifferentialBaseGUID, IsCopyOnly
						from z.fn_DecodeBackupHeader(@HeaderJson);
			end try
			begin catch
				update #Files set ReadError = error_message() where FileID = @FileID;
			end catch
			if @HasRecognizedBackupFileNames = 1 and exists(select * from #Backups b join #Files f on f.FileID = b.FileID where b.FileID = @FileID
				and (b.BackupType <> f.Kind or b.DatabaseName is null or z.fn_StandardizeFileName(b.DatabaseName) <> f.DatabaseName))
			begin
				select @HasRecognizedBackupFileNames = 0;
				goto ___DiscoverSoure___;
			end
			if @HasRecognizedBackupFileNames = 1 and @Stage = 5 and exists(select * from #Backups where FileID = @FileID and BackupType = 5
				and FamilyGUID = @Family and FirstFork = @Fork and LastFork = @Fork and DifferentialBaseGUID = @BaseGUID and DifferentialBaseLSN = @BaseLSN
				and LastLSN > @RequiredLSN and @BaseCopyOnly = 0) break;

		end
		if @Stage = 5
		begin
			select top (1) @DiffID = b.BackupID from #Backups b join #Files f on f.FileID = b.FileID
				where b.BackupType = 5 and b.FamilyGUID = @Family and b.FirstFork = @Fork and b.LastFork = @Fork
					and b.DifferentialBaseGUID = @BaseGUID and b.DifferentialBaseLSN = @BaseLSN and @BaseCopyOnly = 0 and b.LastLSN > @RequiredLSN
				order by b.BackupFinishDate desc, b.LastLSN desc, f.Path, b.Position desc;
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

	if @RecoveryType = 'STANDBY' and (isnull(@IsStandby, 0) = 0 or exists(select * from #MediaPlan))
	begin
		if @Continue = 0 and exists(select * from #Backups where BackupID = @FullID and SoftwareVersionMajor <> convert(int, serverproperty('ProductMajorVersion')))
			throw 50000, 'STANDBY cannot be used when a database-version upgrade is required.', 1;
		select @Name = z.fn_StandardizeFileName(@TargetDatabaseName) + N'.standby', @Original = replace(@PrimaryPath, N'\', N'/');
		select @Folder = coalesce(@StandbyFolder, left(@Original, len(@Original) - charindex(N'/', reverse(@Original)) + 1));
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
		select @SourceName SourceDatabaseName, @Family SourceFamilyGUID, iif(@HasRecognizedBackupFileNames = 1, 'FILENAME', 'HEADER') DiscoveryMode,
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
