/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/020-Backup/modules/1070%20Procedures/z.usp_RestoreDatabase.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/020-Backup/docs/reference/z.usp_RestoreDatabase.md

Discovers user database backup sources and restores their latest supported endpoint, preferring log-only continuation.
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

	declare	@IsLinux bit = z.fn_IsLinux(), @IsFolder bit = 0, @FileExists bit, @IsUrl bit, @BackupDevice nvarchar(4),
			@Automatic bit = iif(@TargetDatabaseName is null, 1, 0),
			@GroupID int, @GroupPrefix nvarchar(4000),
			@DiscoveryPass bit = 0, @DiscoveryRoute int, @DiscoveryLSN numeric(25,0), @DiscoveryEnd numeric(25,0),
			@DiscoveryFamily uniqueidentifier, @DiscoveryFork uniqueidentifier,
			@FileID int, @Path nvarchar(4000), @HeaderJson nvarchar(max), @Sql nvarchar(max),
			@DatabaseID int, @Continue bit = 0, @SourceName sysname, @State tinyint, @IsStandby bit,
			@Outcome varchar(20), @ReachedLSN numeric(25,0), @TargetName sysname,
			@SourceFamily uniqueidentifier, @EligibleSources int, @AliasTargets int, @ExecutionOutcomeID int,
			@RunBatchID uniqueidentifier = newid(), @InitStartTime datetime2(3) = sysutcdatetime(),
			@StepEndTime datetime2(3), @ExecSourceName nvarchar(128), @ErrorNumber int, @ErrorMessage nvarchar(512);

	if @Automatic = 0
	begin
		if @TargetDatabaseName collate Latin1_General_100_CI_AS in (N'master', N'model', N'msdb', N'tempdb')
			or db_id(@TargetDatabaseName) <= 4
			or @TargetDatabaseName = db_name()
			throw 50000, 'System databases and the database hosting this procedure cannot be restore targets.', 1;

		select	@DatabaseID = db_id(@TargetDatabaseName);
		select	@Continue = iif(state = 1 or is_in_standby = 1, 1, 0)
		from sys.databases
		where database_id = @DatabaseID;
		if @Continue = 1
			select	@SourceFamily = family_guid
			from sys.database_recovery_status
			where database_id = @DatabaseID;
	end

	if nullif(trim(translate(@OtherRestoreOptions, nchar(9) + nchar(10) + nchar(11) + nchar(12) + nchar(13), N'     ')), N'') is null
		select	@OtherRestoreOptions = null;

	select	@IsUrl = iif(	left(@BackupPath, 7) collate Latin1_General_100_CI_AS = N'http://'
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

	-- 1. Enumerate and decode backup files (remote URLs identify one single object).
	if @IsUrl = 0
	begin
		select	@IsFolder = file_is_a_directory, @FileExists = file_exists
		from sys.dm_os_file_exists(@BackupPath);
		if @IsFolder is null
			throw 50000, 'BackupPath is inaccessible.', 1;
		if @IsFolder = 0 and @FileExists = 0
			throw 50000, 'BackupPath does not identify an accessible file or folder.', 1;
	end

	create table #RestoreFiles(FileID int identity(1,1) not null primary key, Path nvarchar(4000) collate Latin1_General_100_BIN2 not null, NormalizedPath nvarchar(4000) collate Latin1_General_100_BIN2, FileName nvarchar(4000) collate database_default, Prefix nvarchar(4000) collate database_default, SourceServerName nvarchar(128) collate database_default, SourceInstanceName nvarchar(128) collate database_default, DatabaseName nvarchar(128) collate database_default, BackupTime datetime2(7), BackupType smallint, Inspected bit not null default 0, ReadError nvarchar(2048) collate database_default);

	if @IsFolder = 1
	begin
		insert into #RestoreFiles (Path)
			select	distinct e.full_filesystem_path
			from sys.dm_os_enumerate_filesystem(@BackupPath, N'*') e
			where e.is_directory = 0;
	end
	else
	begin
		insert into #RestoreFiles (Path)
			values (@BackupPath);
	end

	if not exists (select * from #RestoreFiles)
		throw 50000, 'No backup files were found.', 1;

	update #RestoreFiles
		set FileName = right(replace(Path, N'\', N'/'), charindex(N'/', reverse(replace(Path, N'\', N'/')) + N'/') - 1),
			NormalizedPath = iif(@IsLinux = 1, Path, lower(replace(Path, N'/', N'\')));

	update f
		set Prefix = n.Prefix,
			SourceServerName = n.SourceServerName,
			SourceInstanceName = n.SourceInstanceName,
			DatabaseName = n.DatabaseName,
			BackupTime = n.BackupTime,
			BackupType = n.BackupType
	from #RestoreFiles f
		cross apply z.fn_DecodeBackupFileName(f.FileName) n;

	-- Shared tables consumed by target planning and execution.
	create table #RestoreBackups(BackupID int identity(1,1) not null, FileID int not null, Position int not null, BackupType smallint not null, DatabaseName nvarchar(128) collate database_default, FamilyGUID uniqueidentifier, FirstFork uniqueidentifier, LastFork uniqueidentifier, ForkPointLSN numeric(25,0), FirstLSN numeric(25,0), LastLSN numeric(25,0), BackupFinishDate datetime, BackupSetGUID uniqueidentifier, SoftwareVersionMajor int, IsDamaged bit, IsSnapshot bit, HasIncompleteMetaData bit, CheckpointLSN numeric(25,0), DifferentialBaseLSN numeric(25,0), DifferentialBaseGUID uniqueidentifier, IsCopyOnly bit, IsEligible bit not null default 0, primary key (FileID, BackupID));
	create table #RestorePlannedPaths (DatabaseName nvarchar(128) collate database_default not null, Path nvarchar(4000) collate Latin1_General_100_BIN2 not null);
	create table #RestorePlan(Ordinal int not null, DatabaseName nvarchar(128) collate database_default not null, IsContinuation bit not null, BackupType varchar(10) collate database_default not null, BackupFile nvarchar(4000) collate database_default, Position int, FirstLSN numeric(25,0), LastLSN numeric(25,0), Command nvarchar(max) collate database_default not null, primary key (DatabaseName, Ordinal));
	create table #RestoreTargetState(DatabaseName nvarchar(128) collate database_default not null primary key, FamilyGUID uniqueidentifier, InitialDatabaseID int, InitialState tinyint, InitialStandby bit, InitialCreateDate datetime, RecoveryType varchar(10) collate database_default, StandbyFile nvarchar(4000) collate database_default);
	create table #RestoreFileMap (DatabaseName nvarchar(128) collate database_default not null, FileID bigint not null, UniqueID uniqueidentifier, DestinationPath nvarchar(4000) collate Latin1_General_100_BIN2, NormalizedPath nvarchar(4000) collate Latin1_General_100_BIN2, AddedOrdinal int, primary key (DatabaseName, FileID));
	create table #Outcomes (OutcomeID int identity(1,1) not null primary key, DatabaseName nvarchar(128) collate database_default, SourceDatabaseName nvarchar(128) collate database_default, SourceFamilyGUID uniqueidentifier, Status varchar(20) collate database_default not null, LastLSN numeric(25,0), ErrorNumber int, ErrorMessage nvarchar(2048) collate database_default, BackupPath nvarchar(4000) collate Latin1_General_100_BIN2);
	create table #InventoryLabel (MediaName nvarchar(128), MediaSetId uniqueidentifier, FamilyCount int, FamilySequenceNumber int, MediaFamilyId uniqueidentifier, MediaSequenceNumber int, MediaLabelPresent tinyint, MediaDescription nvarchar(255), SoftwareName nvarchar(128), SoftwareVendorId int, MediaDate datetime, Mirror_Count int, IsCompressed bit);

	-- 2. Discover backup headers newest-first per recognized group; unrecognized names run afterward.
	create table #DiscoveryGroups(GroupID int identity(1,1) not null primary key, Prefix nvarchar(4000) collate database_default, Processed bit not null default 0);
	insert into #DiscoveryGroups (Prefix)
		select	distinct Prefix
		from #RestoreFiles
		where Prefix is not null;
	insert into #DiscoveryGroups (Prefix)
		select	null
		where exists (select 1 from #RestoreFiles where Prefix is null);

	create table #DiscoverySources (FamilyGUID uniqueidentifier not null primary key, DatabaseName nvarchar(128) collate database_default, Fork uniqueidentifier, EndLSN numeric(25,0), NativeLSN numeric(25,0), NativeFork uniqueidentifier, NativeBaseGUID uniqueidentifier, NativeBaseLSN numeric(25,0), HasAnchor bit not null default 0, SkipSource bit not null default 0);
	create table #DiscoveryRoutes (RouteID int identity(1,1) not null primary key, FamilyGUID uniqueidentifier, Fork uniqueidentifier, ReachedLSN numeric(25,0), BaseGUID uniqueidentifier, BaseLSN numeric(25,0), CanDiff bit not null, Processed bit not null default 0);

	while exists (select * from #DiscoveryGroups where Processed = 0) or @DiscoveryPass = 0
	begin
		if not exists (select * from #DiscoveryGroups where Processed = 0)
		begin
			-- Revisit recognized groups once so cross-prefix or unknown-filename dependencies can open older bases if needed.
			select	@DiscoveryPass = 1;
			update #DiscoveryGroups set Processed = 0 where Prefix is not null;
			if @@rowcount = 0
				break;
		end

		select	top (1) @GroupID = GroupID, @GroupPrefix = Prefix
		from #DiscoveryGroups
		where Processed = 0
		order by iif(Prefix is null, 1, 0), Prefix;

		update #DiscoveryGroups set Processed = 1 where GroupID = @GroupID;

		while 1 = 1
		begin
			truncate table #DiscoverySources;
			;with s as
			(
				select	b.FamilyGUID, b.DatabaseName, b.LastFork,
						row_number() over (partition by b.FamilyGUID order by b.BackupFinishDate desc, b.Position desc) RowNumber
				from #RestoreBackups b
				where b.IsEligible = 1
					and exists
					(
						select	1
						from #RestoreBackups g
							inner join #RestoreFiles gf on gf.FileID = g.FileID
						where gf.Prefix = @GroupPrefix
							and g.FamilyGUID = b.FamilyGUID
					)
			)
			insert into #DiscoverySources (FamilyGUID, DatabaseName, Fork)
				select	FamilyGUID, DatabaseName, LastFork
				from s
				where RowNumber = 1;

			-- Bind continuation state from native catalog metadata, never filename labels alone.
			update s
				set NativeLSN = n.RedoLSN,
					NativeFork = r.recovery_fork_guid,
					NativeBaseGUID = n.BaseGUID,
					NativeBaseLSN = n.BaseLSN,
					SkipSource = iif(
						(@Automatic = 1 and d.database_id is not null and d.state <> 1 and d.is_in_standby = 0)
						or (@Automatic = 0 and @Continue = 1 and @SourceFamily is not null and s.FamilyGUID <> @SourceFamily),
						1, 0
					)
			from #DiscoverySources s
				left join sys.databases d on d.name collate database_default = coalesce(@TargetDatabaseName, s.DatabaseName)
				left join sys.database_recovery_status r
					on r.database_id = d.database_id
					and r.family_guid = s.FamilyGUID
					and (d.state = 1 or d.is_in_standby = 1)
				outer apply
				(
					select	min(f.redo_start_lsn) RedoLSN,
							max(iif(f.file_id = 1, f.differential_base_guid, null)) BaseGUID,
							max(iif(f.file_id = 1, f.differential_base_lsn, null)) BaseLSN
					from sys.master_files f
					where f.database_id = r.database_id
						and f.type = 0
				) n;

			-- STANDBY can lack native redo metadata; fall back to the latest compatible unrecovered restore record.
			update s
				set NativeLSN = h.last_lsn
			from #DiscoverySources s
				inner join sys.databases d on d.name collate database_default = coalesce(@TargetDatabaseName, s.DatabaseName) and d.is_in_standby = 1
				cross apply
				(
					select	top (1) b.last_lsn, b.family_guid, b.last_recovery_fork_guid, b.type,
							r.restore_type, r.recovery, r.stop_at, r.stop_at_mark_name, r.stop_before, r.restore_date
					from msdb.dbo.restorehistory r
						inner join msdb.dbo.backupset b on b.backup_set_id = r.backup_set_id
					where r.destination_database_name = d.name
					order by r.restore_history_id desc
				) h
			where s.NativeLSN is null
				and h.family_guid = s.FamilyGUID
				and h.last_recovery_fork_guid = s.NativeFork
				and h.restore_type in ('D', 'I', 'L')
				and h.recovery = 0
				and h.stop_at is null
				and h.stop_at_mark_name is null
				and isnull(h.stop_before, 0) = 0
				and h.restore_date is not null
				and (h.type = 'D' or h.restore_date >= d.create_date);

			update s
				set Fork = coalesce(s.NativeFork, a.LastFork, s.Fork)
			from #DiscoverySources s
				outer apply
				(
					select	top (1) b.LastFork
					from #RestoreBackups b
					where b.FamilyGUID = s.FamilyGUID
						and b.BackupType = 1
						and b.IsEligible = 1
					order by b.BackupFinishDate desc, b.Position desc
				) a;

			-- Continuing targets only chase LOGs (or a provably eligible DIFF), never a newer FULL backup's LSN,
			-- and stop once backward reads reach a backup completed at/before NativeLSN or a LOG spanning NativeLSN.
			update s
				set EndLSN = case
						when s.NativeFork is not null and s.NativeLSN is not null then isnull(c.ContinuationEndLSN, s.NativeLSN)
						else a.InitEndLSN
					end,
					HasAnchor = case
						when s.NativeFork is not null and s.NativeLSN is not null then iif(
							exists (
								select	1
								from #RestoreBackups b
								where b.FamilyGUID = s.FamilyGUID
									and b.LastFork = s.NativeFork
									and b.IsEligible = 1
									and (
										b.LastLSN <= s.NativeLSN
										or (b.BackupType = 2 and b.FirstFork = s.NativeFork and b.FirstLSN <= s.NativeLSN)
									)
							), 1, 0)
						else 1
					end
			from #DiscoverySources s
				outer apply
				(
					select	max(b.LastLSN) InitEndLSN
					from #RestoreBackups b
					where b.FamilyGUID = s.FamilyGUID
						and b.LastFork = s.Fork
						and b.IsEligible = 1
				) a
				outer apply
				(
					select	max(b.LastLSN) ContinuationEndLSN
					from #RestoreBackups b
					where b.FamilyGUID = s.FamilyGUID
						and b.FirstFork = s.NativeFork
						and b.LastFork = s.NativeFork
						and b.IsEligible = 1
						and b.LastLSN > s.NativeLSN
						and (
							b.BackupType = 2
							or (
								b.BackupType = 5
								and s.NativeBaseGUID is not null
								and b.DifferentialBaseGUID = s.NativeBaseGUID
								and b.DifferentialBaseLSN = s.NativeBaseLSN
								and (
									not exists (
										select	1
										from #RestoreBackups x
										where x.FamilyGUID = s.FamilyGUID
											and x.LastFork = s.NativeFork
											and x.IsEligible = 1
											and x.LastLSN <= s.NativeLSN
									)
									or exists (
										select	1
										from #RestoreBackups x
										where x.FamilyGUID = s.FamilyGUID
											and x.BackupType = 1
											and x.IsEligible = 1
											and x.FirstFork = s.NativeFork
											and x.LastFork = s.NativeFork
											and x.LastLSN = s.NativeLSN
											and x.BackupSetGUID = s.NativeBaseGUID
											and x.CheckpointLSN = s.NativeBaseLSN
											and x.IsCopyOnly = 0
									)
									or exists (
										select	1
										from sys.databases d
											cross apply (
												select	top (1) rh.restore_type, rh.recovery, rh.stop_at, rh.stop_at_mark_name, rh.stop_before, bs.type, bs.last_lsn, bs.is_copy_only
												from msdb.dbo.restorehistory rh
													inner join msdb.dbo.backupset bs on bs.backup_set_id = rh.backup_set_id
												where rh.destination_database_name = d.name
												order by rh.restore_history_id desc
											) h
										where d.name collate database_default = coalesce(@TargetDatabaseName, s.DatabaseName)
											and h.restore_type = 'D'
											and h.type = 'D'
											and h.recovery = 0
											and h.stop_at is null
											and h.stop_at_mark_name is null
											and isnull(h.stop_before, 0) = 0
											and isnull(h.is_copy_only, 1) = 0
											and h.last_lsn = s.NativeLSN
									)
								)
							)
						)
				) c;

			truncate table #DiscoveryRoutes;
			insert into #DiscoveryRoutes (FamilyGUID, Fork, ReachedLSN, BaseGUID, BaseLSN, CanDiff)
				select	b.FamilyGUID, b.LastFork, b.LastLSN, b.BackupSetGUID, b.CheckpointLSN, iif(b.IsCopyOnly = 0, 1, 0)
				from #RestoreBackups b
					inner join #DiscoverySources s on s.FamilyGUID = b.FamilyGUID and s.Fork = b.LastFork
				where b.BackupType = 1
					and b.IsEligible = 1
					and s.NativeFork is null;

			insert into #DiscoveryRoutes (FamilyGUID, Fork, ReachedLSN, BaseGUID, BaseLSN, CanDiff)
				select	s.FamilyGUID, s.NativeFork, s.NativeLSN, b.BackupSetGUID, b.CheckpointLSN, iif(b.IsCopyOnly = 0, 1, 0)
				from #DiscoverySources s
					outer apply
					(
						select	top (1) b.*
						from #RestoreBackups b
						where b.FamilyGUID = s.FamilyGUID
							and b.BackupType = 1
							and b.IsEligible = 1
							and b.LastFork = s.NativeFork
							and b.LastLSN = s.NativeLSN
							and b.BackupSetGUID = s.NativeBaseGUID
							and b.CheckpointLSN = s.NativeBaseLSN
						order by b.BackupFinishDate desc, b.Position desc
					) b
				where s.NativeLSN is not null
					and s.NativeFork is not null;

			-- Keep full/log and full/differential/log alternatives separate; never apply a differential after a log.
			insert into #DiscoveryRoutes (FamilyGUID, Fork, ReachedLSN, CanDiff)
				select	r.FamilyGUID, r.Fork, b.LastLSN, 0
				from #DiscoveryRoutes r
					inner join #RestoreBackups b
						on b.FamilyGUID = r.FamilyGUID
						and b.FirstFork = r.Fork
						and b.LastFork = r.Fork
						and b.DifferentialBaseGUID = r.BaseGUID
						and b.DifferentialBaseLSN = r.BaseLSN
				where r.CanDiff = 1
					and b.BackupType = 5
					and b.IsEligible = 1
					and b.LastLSN > r.ReachedLSN;

			while exists (select * from #DiscoveryRoutes where Processed = 0)
			begin
				select	top (1) @DiscoveryRoute = RouteID, @DiscoveryFamily = FamilyGUID, @DiscoveryFork = Fork, @DiscoveryLSN = ReachedLSN
				from #DiscoveryRoutes
				where Processed = 0
				order by RouteID;

				while 1 = 1
				begin
					select	@DiscoveryEnd = max(LastLSN)
					from #RestoreBackups
					where FamilyGUID = @DiscoveryFamily
						and IsEligible = 1
						and BackupType = 2
						and FirstFork = @DiscoveryFork
						and LastFork = @DiscoveryFork
						and FirstLSN <= @DiscoveryLSN
						and LastLSN > @DiscoveryLSN;
					if @DiscoveryEnd is null
						break;
					select	@DiscoveryLSN = @DiscoveryEnd;
				end
				update #DiscoveryRoutes set ReachedLSN = @DiscoveryLSN, Processed = 1 where RouteID = @DiscoveryRoute;
			end

			if exists (select * from #DiscoverySources)
				and not exists
				(
					select	*
					from #DiscoverySources s
					where s.SkipSource = 0
						and (
							s.HasAnchor = 0
							or not exists
							(
								select	*
								from #DiscoveryRoutes r
								where r.FamilyGUID = s.FamilyGUID
									and r.Fork = s.Fork
									and r.ReachedLSN >= s.EndLSN
							)
						)
				)
				and @GroupPrefix is not null
				break;

			select	@FileID = null;
			select	top (1) @FileID = FileID, @Path = Path
			from #RestoreFiles
			where Inspected = 0
				and (Prefix = @GroupPrefix or (Prefix is null and @GroupPrefix is null))
			order by BackupTime desc, Path desc;
			if @FileID is null
				break;

			begin try
				select	@HeaderJson = null;
				exec z.usp_ReadBackupHeader @BackupFile = @Path, @HeaderJson = @HeaderJson output, @ReturnResult = 0;
				insert into #RestoreBackups (FileID, Position, BackupType, DatabaseName, FamilyGUID, FirstFork, LastFork, ForkPointLSN, FirstLSN, LastLSN, BackupFinishDate, BackupSetGUID, SoftwareVersionMajor, IsDamaged, IsSnapshot, HasIncompleteMetaData, CheckpointLSN, DifferentialBaseLSN, DifferentialBaseGUID, IsCopyOnly)
					select	@FileID, Position, BackupType, DatabaseName, FamilyGUID, FirstRecoveryForkID, RecoveryForkID, ForkPointLSN, FirstLSN, LastLSN,
							BackupFinishDate, BackupSetGUID, SoftwareVersionMajor, IsDamaged, IsSnapshot, HasIncompleteMetaData,
							CheckpointLSN, DifferentialBaseLSN, DifferentialBaseGUID, IsCopyOnly
					from z.fn_DecodeBackupHeader(@HeaderJson);

				if not exists (select * from #RestoreBackups where FileID = @FileID)
					throw 50000, 'The input file contains no readable backup sets.', 1;

				truncate table #InventoryLabel;
				select	@Sql = N'restore labelonly from ' + @BackupDevice + N' = N''' + replace(@Path, N'''', N'''''') + N''';';
				insert into #InventoryLabel exec(@Sql);
				if (select count(*) from #InventoryLabel) <> 1
					or exists (select * from #InventoryLabel where FamilyCount <> 1 or FamilyCount is null or FamilySequenceNumber <> 1)
					throw 50000, 'Striped or ambiguous media is unsupported; complete single-file media is required.', 1;

				update #RestoreBackups
					set IsEligible = 1
				where FileID = @FileID
					and BackupType in (1, 2, 5)
					and DatabaseName is not null
					and FamilyGUID is not null
					and BackupFinishDate is not null
					and BackupSetGUID is not null
					and FirstLSN is not null
					and LastLSN is not null
					and FirstLSN < LastLSN
					and FirstFork is not null
					and LastFork = FirstFork
					and ForkPointLSN is null
					and isnull(IsDamaged, 1) = 0
					and isnull(IsSnapshot, 1) = 0
					and isnull(HasIncompleteMetaData, 1) = 0;

				if exists (select * from #RestoreBackups where FileID = @FileID and IsEligible = 0)
					insert into #Outcomes (Status, ErrorMessage, BackupPath)
						values ('Ignored', N'Unsupported or invalid backup sets were excluded from source and endpoint selection.', @Path);
			end try
			begin catch
				update #RestoreBackups set IsEligible = 0 where FileID = @FileID;
				update #RestoreFiles set ReadError = error_message() where FileID = @FileID;
				insert into #Outcomes (Status, ErrorNumber, ErrorMessage, BackupPath)
					values ('Failed', error_number(), error_message(), @Path);
			end catch
			update #RestoreFiles set Inspected = 1 where FileID = @FileID;
		end
	end

	-- 3. Resolve eligible source families and build per-target restore plans.
	create table #Sources (FamilyGUID uniqueidentifier not null primary key, DatabaseName nvarchar(128) collate database_default not null, HasFull bit not null, Processed bit not null default 0);
	;with s as
	(
		select	FamilyGUID, DatabaseName,
				row_number() over (partition by FamilyGUID order by BackupFinishDate desc, BackupSetGUID, DatabaseName, Position desc) RowNumber
		from #RestoreBackups
		where IsEligible = 1
	)
	insert into #Sources (FamilyGUID, DatabaseName, HasFull)
		select	s.FamilyGUID, s.DatabaseName,
				convert(bit, iif(exists (select * from #RestoreBackups b where b.FamilyGUID = s.FamilyGUID and b.BackupType = 1 and b.IsEligible = 1), 1, 0))
		from s
		where RowNumber = 1;

	insert into #Outcomes (SourceDatabaseName, SourceFamilyGUID, Status, ErrorMessage)
		select	DatabaseName, FamilyGUID, 'Skipped', N'System database sources are excluded.'
		from #Sources
		where DatabaseName collate Latin1_General_100_CI_AS in (N'master', N'model', N'msdb', N'tempdb');
	delete from #Sources
	where DatabaseName collate Latin1_General_100_CI_AS in (N'master', N'model', N'msdb', N'tempdb');

	if @Automatic = 0
	begin
		begin try
			if @Continue = 0 or @SourceFamily is null
			begin
				if exists
				(
					select	*
					from #Outcomes o
					where o.Status = 'Failed'
						and not exists (select * from #RestoreBackups b inner join #RestoreFiles f on f.FileID = b.FileID where f.Path = o.BackupPath)
				)
					throw 50000, 'Unreadable backup identity prevents proving an unambiguous initialization source.', 1;

				select	@EligibleSources = count(*)
				from #Sources
				where HasFull = 1;

				if @EligibleSources > 1
				begin
					-- In a multi-database folder or media set, match the requested target database name directly.
					select	@EligibleSources = count(*)
					from #Sources s
					where s.HasFull = 1
						and (
							s.DatabaseName = @TargetDatabaseName
							or exists (
								select	1
								from #RestoreBackups b
								where b.FamilyGUID = s.FamilyGUID
									and b.IsEligible = 1
									and b.DatabaseName = @TargetDatabaseName
							)
						);
					if @EligibleSources <> 1
						throw 50000, 'Multiple restorable source database families are ambiguous for the requested destination.', 1;
					select	@SourceFamily = s.FamilyGUID
					from #Sources s
					where s.HasFull = 1
						and (
							s.DatabaseName = @TargetDatabaseName
							or exists (
								select	1
								from #RestoreBackups b
								where b.FamilyGUID = s.FamilyGUID
									and b.IsEligible = 1
									and b.DatabaseName = @TargetDatabaseName
							)
						);
				end
				else if @EligibleSources = 1
					select	@SourceFamily = FamilyGUID
					from #Sources
					where HasFull = 1;
				else
					throw 50000, 'A usable full backup is required to initialize or replace the destination.', 1;
			end

			if not exists (select * from #Sources where FamilyGUID = @SourceFamily)
				throw 50000, 'No available backup source matches the destination database family.', 1;

			-- Known foreign media failures do not invalidate the selected source; unknown identities stay visible unless matched by name.
			update o
				set Status = 'Ignored'
			from #Outcomes o
			where o.Status = 'Failed'
				and exists (select * from #RestoreBackups b inner join #RestoreFiles f on f.FileID = b.FileID where f.Path = o.BackupPath)
				and not exists (select * from #RestoreBackups b inner join #RestoreFiles f on f.FileID = b.FileID where f.Path = o.BackupPath and b.FamilyGUID = @SourceFamily);

			select	@SourceName = DatabaseName
			from #Sources
			where FamilyGUID = @SourceFamily;

			exec z.usp_RestoreDatabaseTarget @BackupPath = @BackupPath, @TargetDatabaseName = @TargetDatabaseName,
				@RecoveryType = @RecoveryType, @ReplaceExisting = @ReplaceExisting, @OtherRestoreOptions = @OtherRestoreOptions,
				@DataFolder = @DataFolder, @LogFolder = @LogFolder, @StandbyFolder = @StandbyFolder,
				@UseDefaultFolder = @UseDefaultFolder, @ShowPlan = @ShowPlan, @DropConnections = @DropConnections,
				@SourceFamilyGUID = @SourceFamily, @Automatic = 0, @Outcome = @Outcome output, @ReachedLSN = @ReachedLSN output;

			insert into #Outcomes (DatabaseName, SourceDatabaseName, SourceFamilyGUID, Status, LastLSN)
				values (@TargetDatabaseName, @SourceName, @SourceFamily, @Outcome, @ReachedLSN);
		end try
		begin catch
			if @ShowPlan = 0
			begin
				select	@StepEndTime = sysutcdatetime(), @ErrorNumber = error_number(), @ErrorMessage = left(error_message(), 512);
				insert into z.BackupRestoreHistory (BatchID, Operation, DatabaseName, SourceDatabaseName, RecoveryType, BackupFile, StartTime, EndTime, DurationMs, Status, ErrorNumber, ErrorMessage)
					values (@RunBatchID, 'Restore', @TargetDatabaseName, @SourceName, @RecoveryType, iif(@IsFolder = 0, left(@BackupPath, 1024), null), @InitStartTime, @StepEndTime, datediff_big(millisecond, @InitStartTime, @StepEndTime), 'Failed', @ErrorNumber, @ErrorMessage);
			end;
			throw;
		end catch;
	end
	else
	begin
		while exists (select * from #Sources where Processed = 0)
		begin
			select	top (1) @SourceFamily = FamilyGUID, @TargetName = DatabaseName, @SourceName = DatabaseName, @Outcome = null, @ReachedLSN = null
			from #Sources
			where Processed = 0
			order by DatabaseName, FamilyGUID;

			update #Sources set Processed = 1 where FamilyGUID = @SourceFamily;
			begin try
				if (select count(*) from #Sources where DatabaseName = @TargetName) > 1
					throw 50000, 'Different source families share a destination database name; automatic restore is ambiguous.', 1;

				-- Reuse a unique existing source-name alias after a source rename; never invent a second secondary.
				select	@AliasTargets = count(*)
				from sys.databases d
					inner join sys.database_recovery_status r on r.database_id = d.database_id
				where r.family_guid = @SourceFamily
					and (d.state = 1 or d.is_in_standby = 1)
					and exists (select * from #RestoreBackups b where b.FamilyGUID = @SourceFamily and b.DatabaseName = d.name collate database_default);

				if @AliasTargets > 1
					throw 50000, 'Several source-name aliases already have continuation targets for this family.', 1;
				if @AliasTargets = 0 and db_id(@TargetName) is null and exists
					(
						select	*
						from sys.databases d
							inner join sys.database_recovery_status r on r.database_id = d.database_id
						where r.family_guid = @SourceFamily
							and (d.state = 1 or d.is_in_standby = 1)
					)
					throw 50000, 'A same-family continuation target exists outside the known source names; specify its destination explicitly.', 1;
				if @AliasTargets = 1
					select	@TargetName = d.name
					from sys.databases d
						inner join sys.database_recovery_status r on r.database_id = d.database_id
					where r.family_guid = @SourceFamily
						and (d.state = 1 or d.is_in_standby = 1)
						and exists (select * from #RestoreBackups b where b.FamilyGUID = @SourceFamily and b.DatabaseName = d.name collate database_default);

				select	@DatabaseID = db_id(@TargetName), @State = null, @IsStandby = 0;
				select	@State = state, @IsStandby = is_in_standby
				from sys.databases
				where database_id = @DatabaseID;

				if @TargetName = db_name() or @DatabaseID <= 4
					insert into #Outcomes (DatabaseName, SourceDatabaseName, SourceFamilyGUID, Status, ErrorMessage)
						values (@TargetName, @SourceName, @SourceFamily, 'Skipped', N'The database hosting this procedure and system targets are excluded.');
				else if @DatabaseID is not null and isnull(@State, -1) <> 1 and @IsStandby = 0
					insert into #Outcomes (DatabaseName, SourceDatabaseName, SourceFamilyGUID, Status, ErrorMessage)
						values (@TargetName, @SourceName, @SourceFamily, 'Skipped', N'Automatic restore does not replace ONLINE or unavailable destinations.');
				else if @DatabaseID is null and exists (select * from #Sources where FamilyGUID = @SourceFamily and HasFull = 0)
					insert into #Outcomes (DatabaseName, SourceDatabaseName, SourceFamilyGUID, Status, ErrorMessage)
						values (@TargetName, @SourceName, @SourceFamily, 'Deferred', N'A full backup is needed to initialize this database.');
				else
				begin
					exec z.usp_RestoreDatabaseTarget @BackupPath = @BackupPath, @TargetDatabaseName = @TargetName,
						@RecoveryType = @RecoveryType, @ReplaceExisting = 0, @OtherRestoreOptions = @OtherRestoreOptions,
						@DataFolder = @DataFolder, @LogFolder = @LogFolder, @StandbyFolder = @StandbyFolder,
						@UseDefaultFolder = @UseDefaultFolder, @ShowPlan = @ShowPlan, @DropConnections = @DropConnections,
						@SourceFamilyGUID = @SourceFamily, @Automatic = 1, @Outcome = @Outcome output, @ReachedLSN = @ReachedLSN output;

					insert into #Outcomes (DatabaseName, SourceDatabaseName, SourceFamilyGUID, Status, LastLSN)
						values (@TargetName, @SourceName, @SourceFamily, @Outcome, @ReachedLSN);
				end
			end try
			begin catch
				delete #RestorePlan where DatabaseName = @TargetName;
				delete #RestoreTargetState where DatabaseName = @TargetName;
				delete #RestoreFileMap where DatabaseName = @TargetName;
				delete #RestorePlannedPaths where DatabaseName = @TargetName;
				insert into #Outcomes (DatabaseName, SourceDatabaseName, SourceFamilyGUID, Status, ErrorNumber, ErrorMessage)
					values (@TargetName, @SourceName, @SourceFamily, 'Failed', error_number(), error_message());
			end catch
		end
	end

	if not exists (select * from #Sources) and not exists (select * from #Outcomes where Status in ('Skipped', 'Failed'))
		insert into #Outcomes (Status, ErrorNumber, ErrorMessage)
			values ('Failed', 50000, N'No eligible database backup sources were found.');

	-- 4. Execute saved restore plans only after all discovery, file mapping and command generation succeed.
	if @ShowPlan = 0
	begin
		declare cExecuteTargets cursor local fast_forward for
			select	o.OutcomeID, o.DatabaseName, o.SourceDatabaseName
			from #Outcomes o
				inner join #RestoreTargetState s on s.DatabaseName = o.DatabaseName
			where o.Status in ('Initialized', 'Advanced', 'AlreadyCurrent')
			order by o.OutcomeID;
		open cExecuteTargets;
		fetch next from cExecuteTargets into @ExecutionOutcomeID, @TargetName, @ExecSourceName;
		while @@fetch_status = 0
		begin
			begin try
				exec z.usp_RestoreDatabaseExecute @TargetDatabaseName = @TargetName, @BatchID = @RunBatchID, @SourceDatabaseName = @ExecSourceName;
			end try
			begin catch
				select	@StepEndTime = sysutcdatetime(), @ErrorNumber = error_number(), @ErrorMessage = left(error_message(), 512);
				update #Outcomes
					set Status = 'Failed', LastLSN = null, ErrorNumber = @ErrorNumber, ErrorMessage = error_message()
				where OutcomeID = @ExecutionOutcomeID;
				if not exists (select 1 from z.BackupRestoreHistory where BatchID = @RunBatchID and Status = 'Failed' and DatabaseName = @TargetName)
					insert into z.BackupRestoreHistory (BatchID, Operation, DatabaseName, SourceDatabaseName, RecoveryType, StartTime, EndTime, DurationMs, Status, ErrorNumber, ErrorMessage)
						values (@RunBatchID, 'Restore', @TargetName, @ExecSourceName, @RecoveryType, @InitStartTime, @StepEndTime, datediff_big(millisecond, @InitStartTime, @StepEndTime), 'Failed', @ErrorNumber, @ErrorMessage);
				if @Automatic = 0
					throw;
			end catch
			fetch next from cExecuteTargets into @ExecutionOutcomeID, @TargetName, @ExecSourceName;
		end
		close cExecuteTargets;
		deallocate cExecuteTargets;

		select	@StepEndTime = sysutcdatetime();
		insert into z.BackupRestoreHistory (BatchID, Operation, DatabaseName, SourceDatabaseName, RecoveryType, BackupFile, StartTime, EndTime, DurationMs, Status, ErrorNumber, ErrorMessage)
			select	@RunBatchID, 'Restore', o.DatabaseName, o.SourceDatabaseName, @RecoveryType, left(o.BackupPath, 1024),
					@InitStartTime, @StepEndTime, datediff_big(millisecond, @InitStartTime, @StepEndTime), 'Failed', o.ErrorNumber, left(o.ErrorMessage, 512)
			from #Outcomes o
			where o.Status = 'Failed'
				and not exists (
					select	1
					from z.BackupRestoreHistory h
					where h.BatchID = @RunBatchID
						and h.Status = 'Failed'
						and isnull(h.DatabaseName, N'') collate database_default = isnull(o.DatabaseName, N'') collate database_default
						and (o.DatabaseName is not null or isnull(h.BackupFile, N'') collate database_default = isnull(left(o.BackupPath, 1024), N'') collate database_default)
				);
	end

	select	DatabaseName, SourceDatabaseName, SourceFamilyGUID, Status, LastLSN, ErrorNumber, ErrorMessage, BackupPath
	from #Outcomes
	order by OutcomeID;

	if @ShowPlan = 0 and exists (select * from #Outcomes where Status = 'Failed')
		throw 50000, 'One or more backup sources failed; inspect the per-database restore outcomes.', 1;
end
