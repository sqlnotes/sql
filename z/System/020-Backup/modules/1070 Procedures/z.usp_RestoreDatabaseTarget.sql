/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/020-Backup/modules/1070%20Procedures/z.usp_RestoreDatabaseTarget.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/020-Backup/docs/reference/z.usp_RestoreDatabase.md

Builds and saves one target restore plan without executing restore commands.
*/
create or alter procedure z.usp_RestoreDatabaseTarget
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
	@DropConnections bit = 1,
	@SourceFamilyGUID uniqueidentifier = null,
	@Automatic bit = 0,
	@Outcome varchar(20) = null output,
	@ReachedLSN numeric(25,0) = null output
)
as
begin
	set nocount, xact_abort on;
	if @@trancount <> 0
		throw 50000, 'RestoreDatabase cannot run inside a user transaction.', 1;
	if @@options & 2 = 2
		throw 50000, 'RestoreDatabase requires implicit transactions to be disabled.', 1;

	if @ReplaceExisting is null or @ShowPlan is null or @UseDefaultFolder is null or @DropConnections is null
		throw 50000, 'ReplaceExisting, ShowPlan, UseDefaultFolder and DropConnections must not be null.', 1;

	select	@BackupPath = nullif(trim(@BackupPath), N''),
			@TargetDatabaseName = nullif(trim(@TargetDatabaseName), N''),
			@RecoveryType = upper(trim(@RecoveryType)),
			@DataFolder = nullif(trim(@DataFolder), N''),
			@LogFolder = nullif(trim(@LogFolder), N''),
			@StandbyFolder = nullif(trim(@StandbyFolder), N'');

	if @BackupPath is null
		throw 50000, 'BackupPath is required.', 1;

	if @RecoveryType is null or @RecoveryType not in ('NORECOVERY', 'RECOVERY', 'STANDBY')
		throw 50000, 'RecoveryType must be NORECOVERY, RECOVERY or STANDBY.', 1;

	declare	@IsLinux bit = z.fn_IsLinux(), @Separator nchar(1), @Path nvarchar(4000), @Folder nvarchar(4000),
			@IsUrl bit, @BackupDevice nvarchar(4), @CrLf nvarchar(2) = nchar(13) + nchar(10),
			@MoveSeparator nvarchar(4) = N',' + nchar(13) + nchar(10) + nchar(9),
			@FileID int, @FullID int, @Position int, @FileListJson nvarchar(max),
			@SourceName sysname, @Family uniqueidentifier, @Fork uniqueidentifier,
			@RequiredLSN numeric(25,0), @StartLSN numeric(25,0), @LogEnd numeric(25,0), @ScanEnd numeric(25,0),
			@NextLSN numeric(25,0), @NextID int, @RouteID int, @RouteLSN numeric(25,0),
			@RouteBase uniqueidentifier, @RouteBaseLSN numeric(25,0), @RouteCopyOnly bit,
			@DatabaseID int, @State tinyint, @IsStandby bit, @Continue bit = 0,
			@NativeFamily uniqueidentifier, @NativeFork uniqueidentifier,
			@HistoryFamily uniqueidentifier, @HistoryFork uniqueidentifier, @HistoryLSN numeric(25,0), @HistoryID int, @HistoryType char(1),
			@FullBackupPath nvarchar(4000), @PrimaryPath nvarchar(4000),
			@DefaultData nvarchar(4000) = convert(nvarchar(4000), serverproperty('InstanceDefaultDataPath')),
			@DefaultLog nvarchar(4000) = convert(nvarchar(4000), serverproperty('InstanceDefaultLogPath')),
			@Name nvarchar(4000), @Original nvarchar(4000), @Destination nvarchar(4000), @Logical sysname, @Type char(1),
			@Slash int, @FinalOption nvarchar(max), @StandbyFile nvarchar(4000), @StandbyNormalized nvarchar(4000),
			@RestoreCount int, @InitialDatabaseID int, @InitialState tinyint, @InitialStandby bit, @InitialCreateDate datetime,
			@SingleUserSql nvarchar(max), @RestoreAccessSql nvarchar(max), @InitialUserAccess tinyint,
			@DiffID int, @BaseGUID uniqueidentifier, @BaseLSN numeric(25,0), @BaseCopyOnly bit,
			@CurrentOrdinal int, @StepType varchar(10), @StepSourceName sysname, @FileSourceName sysname,
			@StepFirstLSN numeric(25,0), @StepLastLSN numeric(25,0), @ReadCount int = 0;

	if nullif(trim(translate(@OtherRestoreOptions, nchar(9) + nchar(10) + nchar(11) + nchar(12) + nchar(13), N'     ')), N'') is null
		select	@OtherRestoreOptions = null;

	-- Strip options owned by procedure parameters while preserving all remaining top-level clauses verbatim.
	if @OtherRestoreOptions is not null
	begin
		declare	@OptPos int = 1, @OptLen int = datalength(@OtherRestoreOptions) / 2, @ClauseStart int = 1,
				@InSingleQuote bit = 0, @InBracket bit = 0, @InLineComment bit = 0, @BlockCommentDepth int = 0, @ParenDepth int = 0,
				@HasStrippedOption bit = 0, @KeptOptions nvarchar(max) = N'',
				@TrimStart int, @TrimEnd int, @Clause nvarchar(max), @CleanPos int, @CleanLen int, @TokenStart int,
				@Token nvarchar(128), @Ch nchar(1), @NextCh nchar(1);

		while @OptPos <= @OptLen + 1
		begin
			select	@Ch = iif(@OptPos <= @OptLen, substring(@OtherRestoreOptions, @OptPos, 1), null),
					@NextCh = iif(@OptPos < @OptLen, substring(@OtherRestoreOptions, @OptPos + 1, 1), null);

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
				while @TrimStart <= @TrimEnd and unicode(substring(@OtherRestoreOptions, @TrimStart, 1)) in (9, 10, 11, 12, 13, 32)
					select	@TrimStart += 1;
				while @TrimEnd >= @TrimStart and unicode(substring(@OtherRestoreOptions, @TrimEnd, 1)) in (9, 10, 11, 12, 13, 32)
					select	@TrimEnd -= 1;

				if @TrimStart <= @TrimEnd
				begin
					select	@Clause = substring(@OtherRestoreOptions, @TrimStart, @TrimEnd - @TrimStart + 1),
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

					if @Token in (N'recovery', N'norecovery', N'standby', N'replace', N'file', N'move')
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
			select	@OtherRestoreOptions = nullif(@KeptOptions, N'');
	end

	select	@Separator = iif(@IsLinux = 1, N'/', N'\'),
			@IsUrl = iif(
				left(@BackupPath, 7) collate Latin1_General_100_CI_AS = N'http://'
				or left(@BackupPath, 8) collate Latin1_General_100_CI_AS = N'https://'
				or left(@BackupPath, 5) collate Latin1_General_100_CI_AS = N's3://',
				1, 0
			);
	select	@BackupDevice = iif(@IsUrl = 1, N'url', N'disk');

	if @IsLinux = 0
	begin
		if @IsUrl = 0
			select	@BackupPath = replace(@BackupPath, N'/', N'\');
		select	@DataFolder = replace(@DataFolder, N'/', N'\'),
				@LogFolder = replace(@LogFolder, N'/', N'\'),
				@StandbyFolder = replace(@StandbyFolder, N'/', N'\');
	end

	if @RecoveryType = 'STANDBY' and @StandbyFolder is not null
		and not exists (select * from sys.dm_os_file_exists(@StandbyFolder) where file_is_a_directory = 1)
		throw 50000, 'The explicit StandbyFolder does not exist or is inaccessible.', 1;

	if object_id('tempdb..#RestoreBackups') is null
		or object_id('tempdb..#RestoreFiles') is null
		or object_id('tempdb..#RestorePlannedPaths') is null
		or object_id('tempdb..#RestorePlan') is null
		or object_id('tempdb..#RestoreTargetState') is null
		or object_id('tempdb..#RestoreFileMap') is null
		or @SourceFamilyGUID is null
		throw 50000, 'RestoreDatabaseTarget requires the caller backup inventory and a source family.', 1;

	select	* into #Files from #RestoreFiles;
	select	* into #Backups from #RestoreBackups where FamilyGUID = @SourceFamilyGUID;

	select	@Family = @SourceFamilyGUID,
			@ReadCount = (select count(*) from #Files where Inspected = 1),
			@DatabaseID = db_id(@TargetDatabaseName);

	select	top (1) @SourceName = DatabaseName
	from #Backups
	where DatabaseName is not null
	order by BackupFinishDate desc, BackupSetGUID, DatabaseName, Position desc;

	-- 1. Validate target database state and determine continuation vs initialization/replacement.
	if @TargetDatabaseName in (N'master', N'model', N'msdb', N'tempdb') or @DatabaseID <= 4 or @TargetDatabaseName = db_name()
		throw 50000, 'System databases and the database hosting this procedure cannot be restore targets.', 1;
	if exists (select * from sys.databases where database_id = @DatabaseID and (source_database_id is not null or group_database_id is not null))
		throw 50000, 'Database snapshots and availability-group databases are not supported restore targets.', 1;

	select	@State = state, @IsStandby = is_in_standby
	from sys.databases
	where database_id = @DatabaseID;
	select	@Continue = iif(@State = 1 or @IsStandby = 1, 1, 0);

	if @Automatic = 1 and @DatabaseID is not null and @Continue = 0
		throw 50000, 'Automatic restore cannot replace an existing destination.', 1;

	if @Continue = 1
	begin
		select	@NativeFamily = family_guid, @NativeFork = recovery_fork_guid
		from sys.database_recovery_status
		where database_id = @DatabaseID;
		if @NativeFamily is null or @NativeFork is null
		begin
			if @Automatic = 1 or @ReplaceExisting = 0
				throw 50000, 'Destination recovery identity is unavailable; automatic reinitialization is disabled.', 1;
			select	@Continue = 0;
		end
		else if @NativeFamily <> @Family
			throw 50000, 'Destination backup family does not match the source.', 1;
	end

	if @DatabaseID is not null and @Continue = 0 and @ReplaceExisting = 0
		throw 50000, 'The destination exists and ReplaceExisting is disabled.', 1;

	select	@InitialDatabaseID = @DatabaseID, @InitialState = @State, @InitialStandby = @IsStandby;
	select	@InitialCreateDate = create_date, @InitialUserAccess = user_access
	from sys.databases
	where database_id = @DatabaseID;

	-- 2. Select initial full base (for initialization/replacement) or resolve current redo state (for continuation).
	create table #FileMap
	(
		FileID bigint not null,
		LogicalName nvarchar(128) collate database_default not null,
		Type char(1) collate database_default not null,
		UniqueID uniqueidentifier,
		OriginalPath nvarchar(4000) collate Latin1_General_100_BIN2,
		DestinationPath nvarchar(4000) collate Latin1_General_100_BIN2,
		NormalizedPath nvarchar(4000) collate Latin1_General_100_BIN2,
		AddedOrdinal int not null default 0,
		SourceDatabaseName nvarchar(128) collate database_default null
	);

	if @Continue = 0
	begin
		-- Select the recovery branch of the newest full, then compare legal endpoints within that branch.
		select	top (1) @Fork = LastFork
		from #Backups
		where BackupType = 1
			and IsEligible = 1
		order by BackupFinishDate desc, BackupSetGUID, LastFork, FileID, Position desc;

		create table #FullRoutes (BackupID int not null primary key, EndLSN numeric(25,0) not null, NeedsDiff bit not null default 0, Processed bit not null default 0);
		insert #FullRoutes (BackupID, EndLSN)
			select	BackupID, LastLSN
			from #Backups
			where BackupType = 1
				and IsEligible = 1
				and FirstFork = @Fork
				and LastFork = @Fork;

		while exists (select * from #FullRoutes where Processed = 0)
		begin
			select	top (1) @RouteID = r.BackupID, @RouteLSN = r.EndLSN, @RouteBase = b.BackupSetGUID, @RouteBaseLSN = b.CheckpointLSN, @RouteCopyOnly = b.IsCopyOnly
			from #FullRoutes r
				inner join #Backups b on b.BackupID = r.BackupID
			where r.Processed = 0
			order by r.BackupID;

			while 1 = 1
			begin
				select	@ScanEnd = max(LastLSN)
				from #Backups
				where BackupType = 2
					and IsEligible = 1
					and FirstFork = @Fork
					and LastFork = @Fork
					and FirstLSN <= @RouteLSN
					and LastLSN > @RouteLSN;
				if @ScanEnd is null
					break;
				select	@RouteLSN = @ScanEnd;
			end

			select	@ScanEnd = max(LastLSN)
			from #Backups
			where BackupType = 5
				and IsEligible = 1
				and FirstFork = @Fork
				and LastFork = @Fork
				and @RouteCopyOnly = 0
				and DifferentialBaseGUID = @RouteBase
				and DifferentialBaseLSN = @RouteBaseLSN
				and LastLSN > @RouteLSN;
			if @ScanEnd is not null
			begin
				select	@RouteLSN = @ScanEnd;
				update #FullRoutes set NeedsDiff = 1 where BackupID = @RouteID;
			end

			while 1 = 1
			begin
				select	@ScanEnd = max(LastLSN)
				from #Backups
				where BackupType = 2
					and IsEligible = 1
					and FirstFork = @Fork
					and LastFork = @Fork
					and FirstLSN <= @RouteLSN
					and LastLSN > @RouteLSN;
				if @ScanEnd is null
					break;
				select	@RouteLSN = @ScanEnd;
			end
			update #FullRoutes set EndLSN = @RouteLSN, Processed = 1 where BackupID = @RouteID;
		end

		select	top (1) @FullID = b.BackupID, @FullBackupPath = f.Path, @SourceName = b.DatabaseName
		from #FullRoutes r
			inner join #Backups b on b.BackupID = r.BackupID
			inner join #Files f on f.FileID = b.FileID
		order by r.EndLSN desc, r.NeedsDiff, b.BackupFinishDate desc, b.LastLSN desc, b.BackupSetGUID, f.Path, b.Position desc;

		if @FullID is null
			throw 50000, 'A usable full backup is required to initialize or replace the destination.', 1;

		select	@BaseGUID = BackupSetGUID, @BaseLSN = CheckpointLSN, @BaseCopyOnly = IsCopyOnly,
				@RequiredLSN = LastLSN, @Fork = LastFork, @Position = Position
		from #Backups
		where BackupID = @FullID;

		exec z.usp_ReadBackupFileList @BackupFile = @FullBackupPath, @Position = @Position, @FileListJson = @FileListJson output, @ReturnResult = 0;
		if exists (
			select	*
			from z.fn_DecodeBackupFileList(@FileListJson)
			where Type is null or Type not in ('D', 'L') or IsPresent = 0
				or LogicalName is null or FileID is null or UniqueID is null or PhysicalName is null or DropLSN > 0
		)
			throw 50000, 'Only complete ROWS and LOG file layouts are supported; FILESTREAM and partial layouts require an explicit restore.', 1;

		insert #FileMap (FileID, LogicalName, Type, UniqueID, OriginalPath, AddedOrdinal, SourceDatabaseName)
			select	FileID, LogicalName, Type, UniqueID, PhysicalName, 1, @SourceName
			from z.fn_DecodeBackupFileList(@FileListJson);
		if not exists (select * from #FileMap where FileID = 1 and Type = 'D')
			throw 50000, 'The backup primary data file is missing.', 1;
	end
	else
	begin
		select	@FullBackupPath = null;
		select	@PrimaryPath = physical_name
		from sys.master_files
		where database_id = @DatabaseID
			and file_id = 1;
		select	@NativeFamily = family_guid, @NativeFork = recovery_fork_guid
		from sys.database_recovery_status
		where database_id = @DatabaseID;
		if @NativeFamily is null or @NativeFamily <> @Family
			throw 50000, 'Destination backup family does not match the source.', 1;

		select	@RequiredLSN = min(redo_start_lsn)
		from sys.master_files
		where database_id = @DatabaseID
			and type = 0;
		select	top (1) @Fork = redo_start_fork_guid
		from sys.master_files
		where database_id = @DatabaseID
			and type = 0
			and redo_start_lsn is not null
		order by file_id;

		if exists (
			select	*
			from sys.master_files
			where database_id = @DatabaseID
				and type = 0
				and redo_start_lsn is not null
				and (redo_start_fork_guid is null or redo_start_fork_guid <> @Fork)
		)
			throw 50000, 'The destination has inconsistent file recovery forks.', 1;

		select	@LogEnd = @RequiredLSN;
		while @LogEnd is not null
		begin
			select	@ScanEnd = max(LastLSN)
			from #Backups
			where BackupType = 2
				and IsEligible = 1
				and FirstFork = @Fork
				and LastFork = @Fork
				and FirstLSN <= @LogEnd
				and LastLSN > @LogEnd;
			if @ScanEnd is null
				break;
			select	@LogEnd = @ScanEnd;
		end

		-- A matching full header at the current redo position proves differential eligibility without history.
		select	top (1) @BaseGUID = b.BackupSetGUID, @BaseLSN = b.CheckpointLSN, @BaseCopyOnly = b.IsCopyOnly
		from #Backups b
			inner join sys.master_files f on f.database_id = @DatabaseID and f.file_id = 1
		where b.BackupType = 1
			and b.FamilyGUID = @Family
			and b.LastFork = @Fork
			and b.FirstFork = @Fork
			and b.LastLSN = @RequiredLSN
			and b.BackupSetGUID = f.differential_base_guid
			and b.CheckpointLSN = f.differential_base_lsn
		order by b.BackupFinishDate desc, b.Position desc;

		-- Only absent native progress or an unproven differential base needs the latest restore record.
		if @RequiredLSN is null or @Fork is null or (@BaseGUID is null and exists
		(
			select	*
			from #Backups b
				left join sys.master_files f on f.database_id = @DatabaseID and f.file_id = 1
			where b.BackupType = 5
				and b.IsEligible = 1
				and b.FamilyGUID = @Family
				and b.FirstFork = @Fork
				and b.LastFork = @Fork
				and b.LastLSN > @RequiredLSN
				and (b.LastLSN > @LogEnd or @LogEnd is null)
				and (
					f.differential_base_guid is null
					or f.differential_base_lsn is null
					or (b.DifferentialBaseGUID = f.differential_base_guid and b.DifferentialBaseLSN = f.differential_base_lsn)
				)
		))
		begin
			select	top (1) @HistoryID = r.restore_history_id, @HistoryFamily = b.family_guid, @HistoryFork = b.last_recovery_fork_guid,
					@HistoryLSN = b.last_lsn, @HistoryType = b.type,
					@BaseGUID = iif(b.type = 'D', b.backup_set_uuid, null),
					@BaseLSN = iif(b.type = 'D', b.checkpoint_lsn, null),
					@BaseCopyOnly = iif(b.type = 'D', b.is_copy_only, null)
			from msdb.dbo.restorehistory r
				inner join msdb.dbo.backupset b on b.backup_set_id = r.backup_set_id
			where r.destination_database_name = @TargetDatabaseName
			order by r.restore_history_id desc;

			if @HistoryID is null or @HistoryFamily is null or @HistoryFamily <> @Family or @HistoryFork is null or @HistoryFork <> @NativeFork
				or exists (
					select	*
					from msdb.dbo.restorehistory
					where restore_history_id = @HistoryID
						and (
							restore_type is null or restore_type not in ('D', 'I', 'L')
							or recovery is null or recovery <> 0
							or stop_at is not null or stop_at_mark_name is not null or stop_before = 1
							or restore_date is null or (@HistoryType <> 'D' and restore_date < @InitialCreateDate)
						)
				)
			begin
				if @RequiredLSN is null or @Fork is null
					throw 50000, 'Native metadata is insufficient and compatible unrecovered restore history is unavailable.', 1;
				select	@BaseGUID = null, @BaseLSN = null, @BaseCopyOnly = null;
			end

			if @RequiredLSN is null or @Fork is null
			begin
				if @IsStandby <> 1
					throw 50000, 'Destination native redo position is unavailable.', 1;
				select	@RequiredLSN = @HistoryLSN, @Fork = @NativeFork;
			end

			if @HistoryLSN <> @RequiredLSN
				select	@BaseGUID = null, @BaseLSN = null, @BaseCopyOnly = null;
		end

		if @RequiredLSN is null or @Fork is null or @NativeFork is null or @Fork <> @NativeFork
			throw 50000, 'Destination redo position or recovery fork is unavailable or inconsistent.', 1;

		if exists (select * from sys.master_files where database_id = @DatabaseID and type not in (0, 1))
			throw 50000, 'Only ROWS and LOG layouts support continuation through this procedure.', 1;

		insert #FileMap (FileID, LogicalName, Type, UniqueID, OriginalPath, DestinationPath, NormalizedPath, SourceDatabaseName)
			select	file_id, name, iif(type = 1, 'L', 'D'), file_guid, physical_name, physical_name,
					iif(@IsLinux = 1, physical_name, lower(replace(physical_name, N'/', N'\'))), @SourceName
			from sys.master_files
			where database_id = @DatabaseID
				and type in (0, 1);
	end

	-- 3. Build the ordered media sequence (preferring logs; using differential only when it extends further).
	select	@StartLSN = @RequiredLSN, @LogEnd = @RequiredLSN;
	while 1 = 1
	begin
		select	@ScanEnd = max(LastLSN)
		from #Backups
		where BackupType = 2
			and IsEligible = 1
			and FirstFork = @Fork
			and LastFork = @Fork
			and FirstLSN <= @LogEnd
			and LastLSN > @LogEnd;
		if @ScanEnd is null
			break;
		select	@LogEnd = @ScanEnd;
	end

	if @BaseGUID is not null and @BaseCopyOnly = 0
	begin
		select	top (1) @DiffID = BackupID
		from #Backups
		where BackupType = 5
			and IsEligible = 1
			and FirstFork = @Fork
			and LastFork = @Fork
			and DifferentialBaseGUID = @BaseGUID
			and DifferentialBaseLSN = @BaseLSN
			and LastLSN > @LogEnd
		order by LastLSN desc, BackupFinishDate desc, Position desc;
	end

	if @DiffID is not null
		select	@RequiredLSN = LastLSN from #Backups where BackupID = @DiffID;

	if @Continue = 1 and @DiffID is null
		and not exists (select * from #Backups where BackupType in (1, 2) and IsEligible = 1)
		and exists (select * from #Backups where BackupType = 5 and LastLSN > @StartLSN)
		throw 50000, 'The differential requires a matching unrecovered full backup with no intervening log restore.', 1;

	delete b
	from #Backups b
	where exists (select * from #Backups d where d.BackupSetGUID = b.BackupSetGUID and d.BackupID < b.BackupID)
		and b.BackupID <> isnull(@FullID, -1)
		and b.BackupID <> isnull(@DiffID, -1);

	create table #MediaPlan
	(
		Ordinal int identity(1,1) not null primary key,
		BackupID int,
		BackupType varchar(10) collate database_default,
		BackupFile nvarchar(4000) collate database_default,
		Position int,
		FirstLSN numeric(25,0),
		LastLSN numeric(25,0),
		Command nvarchar(max) collate database_default
	);

	if @Continue = 0
		insert #MediaPlan (BackupID, BackupType, BackupFile, Position, FirstLSN, LastLSN)
			select	b.BackupID, 'FULL', f.Path, b.Position, b.FirstLSN, b.LastLSN
			from #Backups b
				inner join #Files f on f.FileID = b.FileID
			where b.BackupID = @FullID;

	if @DiffID is not null
		insert #MediaPlan (BackupID, BackupType, BackupFile, Position, FirstLSN, LastLSN)
			select	b.BackupID, 'DIFF', f.Path, b.Position, b.FirstLSN, b.LastLSN
			from #Backups b
				inner join #Files f on f.FileID = b.FileID
			where b.BackupID = @DiffID;

	while exists (select * from #Backups where BackupType = 2 and IsEligible = 1 and FirstFork = @Fork and LastFork = @Fork and LastLSN > @RequiredLSN)
	begin
		select	@NextID = null;
		select	top (1) @NextID = b.BackupID, @NextLSN = b.LastLSN
		from #Backups b
			inner join #Files f on f.FileID = b.FileID
		where b.BackupType = 2
			and b.IsEligible = 1
			and b.FirstFork = @Fork
			and b.LastFork = @Fork
			and b.FirstLSN <= @RequiredLSN
			and b.LastLSN > @RequiredLSN
		order by b.LastLSN desc, b.FirstLSN, f.Path;

		if @NextID is null
			throw 50000, 'The available transaction-log backups have a gap after the required restore LSN.', 1;

		insert #MediaPlan (BackupID, BackupType, BackupFile, Position, FirstLSN, LastLSN)
			select	b.BackupID, 'LOG', f.Path, b.Position, b.FirstLSN, b.LastLSN
			from #Backups b
				inner join #Files f on f.FileID = b.FileID
			where b.BackupID = @NextID;
		select	@RequiredLSN = @NextLSN;
	end

	if exists (select * from #Backups where BackupType = 2 and IsEligible = 0 and FirstFork = @Fork and LastFork = @Fork and LastLSN > @RequiredLSN)
		throw 50000, 'Invalid or unsupported pending transaction-log media prevents reaching the latest available LSN.', 1;

	-- 4. Map newly introduced database files in restore order and validate path collisions.
	create table #StepFiles
	(
		FileID bigint, LogicalName nvarchar(128) collate database_default, Type char(1) collate database_default, UniqueID uniqueidentifier,
		PhysicalName nvarchar(4000) collate database_default, CreateLSN numeric(25,0), DropLSN numeric(25,0), IsPresent bit
	);

	declare cLogs cursor local fast_forward for
		select	p.Ordinal, p.BackupType, p.BackupFile, p.Position, p.FirstLSN, p.LastLSN, b.DatabaseName
		from #MediaPlan p
			inner join #Backups b on b.BackupID = p.BackupID
		where p.BackupType in ('DIFF', 'LOG')
		order by p.Ordinal;
	open cLogs;
	fetch next from cLogs into @CurrentOrdinal, @StepType, @Path, @Position, @StepFirstLSN, @StepLastLSN, @StepSourceName;
	while @@fetch_status = 0
	begin
		exec z.usp_ReadBackupFileList @BackupFile = @Path, @Position = @Position, @FileListJson = @FileListJson output, @ReturnResult = 0;
		truncate table #StepFiles;
		insert #StepFiles (FileID, LogicalName, Type, UniqueID, PhysicalName, CreateLSN, DropLSN, IsPresent)
			select	FileID, LogicalName, Type, UniqueID, PhysicalName, CreateLSN, DropLSN, IsPresent
			from z.fn_DecodeBackupFileList(@FileListJson);

		if exists (
			select	*
			from #StepFiles
			where FileID is null or LogicalName is null or Type is null or Type not in ('D', 'L')
				or UniqueID is null or PhysicalName is null or (@StepType = 'DIFF' and IsPresent = 0) or DropLSN > 0
		)
			or exists (select * from #StepFiles group by FileID having count(*) > 1)
			or exists (select * from #StepFiles group by LogicalName having count(*) > 1)
			or exists (select * from #StepFiles group by UniqueID having count(*) > 1)
			throw 50000, 'A pending differential or log has incomplete, removed, reused or unsupported file metadata.', 1;

		if exists (
			select	*
			from #StepFiles l
				inner join #FileMap m on m.FileID = l.FileID or m.LogicalName = l.LogicalName or m.UniqueID = l.UniqueID
			where m.FileID <> l.FileID or m.LogicalName <> l.LogicalName or m.UniqueID <> l.UniqueID or m.Type <> l.Type
		)
			throw 50000, 'A pending differential or log reuses or changes an existing file identity.', 1;

		if @StepType = 'DIFF' and exists (
			select	*
			from #FileMap m
			where not exists (select * from #StepFiles l where l.FileID = m.FileID and l.UniqueID = m.UniqueID and l.LogicalName = m.LogicalName and l.Type = m.Type)
		)
			throw 50000, 'The differential removes a mapped file; use an explicit restore sequence.', 1;

		if @StepType = 'LOG' and exists (
			select	*
			from #StepFiles l
			where not exists (select * from #FileMap m where m.FileID = l.FileID)
				and (l.CreateLSN is null or l.CreateLSN < @StepFirstLSN or l.CreateLSN >= @StepLastLSN)
		)
			throw 50000, 'A new log file must be created within that transaction-log backup interval to use MOVE.', 1;

		insert #FileMap (FileID, LogicalName, Type, UniqueID, OriginalPath, AddedOrdinal, SourceDatabaseName)
			select	l.FileID, l.LogicalName, l.Type, l.UniqueID, l.PhysicalName, @CurrentOrdinal, @StepSourceName
			from #StepFiles l
			where not exists (select * from #FileMap m where m.FileID = l.FileID);

		fetch next from cLogs into @CurrentOrdinal, @StepType, @Path, @Position, @StepFirstLSN, @StepLastLSN, @StepSourceName;
	end
	close cLogs;
	deallocate cLogs;

	if exists (select * from #FileMap where DestinationPath is null and SourceDatabaseName <> @TargetDatabaseName)
		and (@TargetDatabaseName like N'%[<>:"/\|?*]%' or right(@TargetDatabaseName, 1) in (N'.', N' '))
		throw 50000, 'The destination database name cannot be used safely in physical filenames.', 1;

	declare cFileMap cursor local fast_forward for
		select	FileID, LogicalName, Type, OriginalPath, SourceDatabaseName
		from #FileMap
		where DestinationPath is null
		order by AddedOrdinal, FileID;
	open cFileMap;
	fetch next from cFileMap into @FileID, @Logical, @Type, @Original, @FileSourceName;
	while @@fetch_status = 0
	begin
		select	@Original = replace(@Original, N'\', N'/'),
				@Slash = charindex(N'/', reverse(replace(@Original, N'\', N'/')));
		select	@Name = iif(@Slash = 0, @Original, right(@Original, @Slash - 1)),
				@Folder = iif(@Slash = 0, null, left(@Original, len(@Original) - @Slash + 1));
		if @IsLinux = 0
			select	@Folder = replace(@Folder, N'/', N'\');
		if @TargetDatabaseName <> @FileSourceName
			select	@Name = iif(charindex(@FileSourceName, @Name) > 0, replace(@Name, @FileSourceName, @TargetDatabaseName), @TargetDatabaseName + N'_' + @Name);

		select	@Destination = iif(@Type = 'L', @LogFolder, @DataFolder);
		if @Destination is null
			select	@Destination = iif(@UseDefaultFolder = 1, iif(@Type = 'L', @DefaultLog, @DefaultData), @Folder);
		if nullif(trim(@Destination), N'') is null
			throw 50000, 'The selected original or instance-default destination directory is unavailable in metadata.', 1;
		if @Name is null or @Name = N'' or @Name in (N'.', N'..')
			throw 50000, 'A backup physical filename is invalid.', 1;

		select	@Destination = @Destination + iif(right(@Destination, 1) in (N'/', N'\'), N'', @Separator) + @Name;
		if len(@Destination) > 260
			throw 50000, 'A destination database-file path exceeds 260 characters.', 1;

		update #FileMap
			set DestinationPath = @Destination,
				NormalizedPath = iif(@IsLinux = 1, @Destination, lower(replace(@Destination, N'/', N'\')))
		where FileID = @FileID;
		fetch next from cFileMap into @FileID, @Logical, @Type, @Original, @FileSourceName;
	end
	close cFileMap;
	deallocate cFileMap;

	select	@PrimaryPath = DestinationPath from #FileMap where FileID = 1;
	if exists (select * from #FileMap where DestinationPath is null)
		throw 50000, 'A destination file mapping is incomplete.', 1;
	if exists (select * from #FileMap group by NormalizedPath having count(*) > 1)
		throw 50000, 'Multiple files resolve to the same destination path.', 1;
	if exists (select * from #FileMap m inner join #Files f on f.NormalizedPath = m.NormalizedPath)
		throw 50000, 'A destination database file collides with an input backup file.', 1;
	if exists (
		select	*
		from #FileMap m
			inner join sys.master_files f
				on m.NormalizedPath = iif(@IsLinux = 1, f.physical_name, lower(replace(f.physical_name, N'/', N'\'))) collate Latin1_General_100_BIN2
		where @DatabaseID is null or f.database_id <> @DatabaseID
	)
		throw 50000, 'A destination file belongs to another database.', 1;
	if exists (
		select	*
		from #FileMap m
			cross apply sys.dm_os_file_exists(m.DestinationPath) e
		where (@Continue = 0 or m.AddedOrdinal > 0)
			and (e.file_exists = 1 or e.file_is_a_directory = 1)
			and not exists (
				select	*
				from sys.master_files f
				where f.database_id = @DatabaseID
					and (@Continue = 0 or (f.file_id = m.FileID and f.file_guid = m.UniqueID))
					and m.NormalizedPath = iif(@IsLinux = 1, f.physical_name, lower(replace(f.physical_name, N'/', N'\'))) collate Latin1_General_100_BIN2
			)
	)
		throw 50000, 'A destination path already exists outside the destination database; overwrite refused.', 1;

	if @RecoveryType = 'STANDBY' and (isnull(@IsStandby, 0) = 0 or exists (select * from #MediaPlan))
	begin
		if @Continue = 0 and exists (select * from #Backups where BackupID = @FullID and SoftwareVersionMajor <> convert(int, serverproperty('ProductMajorVersion')))
			throw 50000, 'STANDBY cannot be used when a database-version upgrade is required.', 1;

		select	@Name = z.fn_StandardizeFileName(@TargetDatabaseName) + N'.standby',
				@Original = replace(@PrimaryPath, N'\', N'/');
		select	@Folder = coalesce(@StandbyFolder, left(@Original, len(@Original) - charindex(N'/', reverse(@Original)) + 1));
		if @IsLinux = 0
			select	@Folder = replace(@Folder, N'/', N'\');
		if @Folder is null or not exists (select * from sys.dm_os_file_exists(@Folder) where file_is_a_directory = 1)
			throw 50000, 'The standby destination directory is unavailable.', 1;

		select	@StandbyFile = @Folder + iif(right(@Folder, 1) in (N'/', N'\'), N'', @Separator) + @Name;
		if len(@StandbyFile) > 260
			throw 50000, 'The standby path exceeds 260 characters.', 1;

		select	@StandbyNormalized = iif(@IsLinux = 1, @StandbyFile, lower(replace(@StandbyFile, N'/', N'\')));
		if exists (
			select	*
			from sys.master_files f
			where @StandbyNormalized collate Latin1_General_100_BIN2 = iif(@IsLinux = 1, f.physical_name, lower(replace(f.physical_name, N'/', N'\'))) collate Latin1_General_100_BIN2
		)
			or exists (select * from #FileMap where NormalizedPath = @StandbyNormalized collate Latin1_General_100_BIN2)
			or exists (select * from #Files where NormalizedPath = @StandbyNormalized collate Latin1_General_100_BIN2)
			throw 50000, 'The standby path collides with a database or backup file.', 1;

		if exists (select * from sys.dm_os_file_exists(@StandbyFile) where file_is_a_directory = 1 or file_exists = 1)
			and isnull(@IsStandby, 0) <> 1
			throw 50000, 'The standby output path already exists; overwrite refused.', 1;
	end

	-- Detect cross-target output path collisions across the whole restore batch before execution.
	if exists (select * from #FileMap m inner join #RestorePlannedPaths p on p.Path = m.NormalizedPath where p.DatabaseName <> @TargetDatabaseName)
		or (@StandbyNormalized is not null and exists (select * from #RestorePlannedPaths where DatabaseName <> @TargetDatabaseName and Path = @StandbyNormalized collate Latin1_General_100_BIN2))
		throw 50000, 'The destination paths collide with another database in this restore batch.', 1;

	insert #RestorePlannedPaths (DatabaseName, Path)
		select	@TargetDatabaseName, NormalizedPath from #FileMap;
	if @StandbyNormalized is not null
		insert #RestorePlannedPaths (DatabaseName, Path)
			values (@TargetDatabaseName, @StandbyNormalized);

	-- 5. Generate exact RESTORE, FINALIZE and SINGLEUSER/ACCESSMODE SQL commands.
	select	@FinalOption = case @RecoveryType
				when 'STANDBY' then N'standby = N''' + replace(@StandbyFile, N'''', N'''''') + N''''
				when 'RECOVERY' then N'recovery'
				else N'norecovery'
			end,
			@RestoreCount = (select count(*) from #MediaPlan);

	update p
		set Command = N'restore ' + iif(p.BackupType in ('FULL', 'DIFF'), N'database ', N'log ') + quotename(@TargetDatabaseName)
			+ N' from ' + @BackupDevice + N' = N''' + replace(p.BackupFile, N'''', N'''''') + N'''' + @CrLf
			+ N'with ' + coalesce(a.Moves + N',' + @CrLf + nchar(9), N'') + N'file = ' + convert(nvarchar(11), p.Position)
			+ iif(p.BackupType = 'FULL' and @DatabaseID is not null and @ReplaceExisting = 1, N', replace', N'')
			+ N', norecovery' + coalesce(N', ' + @OtherRestoreOptions, N'') + N';'
	from #MediaPlan p
		outer apply
		(
			select	string_agg(
						convert(nvarchar(max), N'move N''' + replace(m.LogicalName collate database_default, N'''', N'''''')
							+ N''' to N''' + replace(m.DestinationPath collate database_default, N'''', N'''''') + N''''),
						@MoveSeparator
					) within group (order by m.FileID) Moves
			from #FileMap m
			where m.AddedOrdinal = p.Ordinal
		) a;

	if @RecoveryType <> 'NORECOVERY' and not (@RestoreCount = 0 and isnull(@IsStandby, 0) = 1 and @RecoveryType = 'STANDBY')
		insert #MediaPlan (BackupType, Command)
			values ('FINALIZE', N'restore database ' + quotename(@TargetDatabaseName) + N' with ' + @FinalOption + N';');

	-- Only an ONLINE destination can admit user connections; RESTORING and other unavailable states need no access change.
	if @DropConnections = 1 and @DatabaseID is not null and @InitialState = 0 and exists(select * from #MediaPlan)
	begin
		select	@SingleUserSql = N'alter database ' + quotename(@TargetDatabaseName) + N' set single_user with rollback immediate;';
		select	@RestoreAccessSql = N'alter database ' + quotename(@TargetDatabaseName) + N' set '
				+ case @InitialUserAccess when 0 then N'multi_user' when 1 then N'single_user' when 2 then N'restricted_user' end + N';';
	end

	create table #Plan
	(
		Ordinal int not null primary key,
		DatabaseName nvarchar(128) collate database_default not null,
		IsContinuation bit not null,
		BackupType varchar(10) collate database_default not null,
		BackupFile nvarchar(4000) collate database_default,
		Position int,
		FirstLSN numeric(25,0),
		LastLSN numeric(25,0),
		Command nvarchar(max) collate database_default not null
	);

	insert #Plan (Ordinal, DatabaseName, IsContinuation, BackupType, BackupFile, Position, FirstLSN, LastLSN, Command)
		select	Ordinal, @TargetDatabaseName, @Continue, BackupType, BackupFile, Position, FirstLSN, LastLSN, Command
		from #MediaPlan;

	if @SingleUserSql is not null
	begin
		insert #Plan (Ordinal, DatabaseName, IsContinuation, BackupType, Command)
			values (0, @TargetDatabaseName, @Continue, 'SINGLEUSER', @SingleUserSql);
		select	@RestoreAccessSql = N'if exists(select * from #RestoreExecutionState s inner join sys.databases d on d.database_id = '
				+ convert(nvarchar(11), @InitialDatabaseID) + N' where s.StateID = 1 and s.AccessChanged = 1 and d.name = N'''
				+ replace(@TargetDatabaseName, N'''', N'''''') + N''' and d.create_date = s.AccessCreateDate and d.state = 0)'
				+ @CrLf + N'begin' + @CrLf + nchar(9) + @RestoreAccessSql
				+ @CrLf + nchar(9) + N'update #RestoreExecutionState set AccessChanged = 0 where StateID = 1;'
				+ @CrLf + N'end;';
		insert #Plan (Ordinal, DatabaseName, IsContinuation, BackupType, Command)
			select	max(Ordinal) + 1, @TargetDatabaseName, @Continue, 'ACCESSMODE', @RestoreAccessSql
			from #Plan;
	end

	insert #RestorePlan (Ordinal, DatabaseName, IsContinuation, BackupType, BackupFile, Position, FirstLSN, LastLSN, Command)
		select	Ordinal, DatabaseName, IsContinuation, BackupType, BackupFile, Position, FirstLSN, LastLSN, Command
		from #Plan;
	insert #RestoreTargetState (DatabaseName, FamilyGUID, InitialDatabaseID, InitialState, InitialStandby, InitialCreateDate, RecoveryType, StandbyFile)
		values (@TargetDatabaseName, @Family, @InitialDatabaseID, @InitialState, @InitialStandby, @InitialCreateDate, @RecoveryType, @StandbyFile);
	insert #RestoreFileMap (DatabaseName, FileID, UniqueID, DestinationPath, NormalizedPath, AddedOrdinal)
		select	@TargetDatabaseName, FileID, UniqueID, DestinationPath, NormalizedPath, AddedOrdinal
		from #FileMap;

	select	@ReachedLSN = @RequiredLSN,
			@Outcome = case
				when @ShowPlan = 1 then 'Planned'
				when @Continue = 0 then 'Initialized'
				when @RestoreCount > 0 then 'Advanced'
				else 'AlreadyCurrent'
			end;

	if @ShowPlan = 1
	begin
		select	* from #Plan order by Ordinal;
		select	FileID, LogicalName, Type, OriginalPath, DestinationPath, @StandbyFile StandbyFile, AddedOrdinal, @TargetDatabaseName DatabaseName
		from #FileMap
		order by AddedOrdinal, FileID;
		select	@SourceName SourceDatabaseName, @Family SourceFamilyGUID,
				iif(exists (select * from #Files where Prefix is null), 'HEADER', 'FILENAME') DiscoveryMode,
				(select count(*) from #Files) FilesDiscovered, @ReadCount HeadersRead;
		return;
	end
end
