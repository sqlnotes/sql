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

	declare @IsLinux bit = z.fn_IsLinux(), @Separator nchar(1), @IsFolder bit = 0, @FileExists bit,
		@IsUrl bit, @BackupDevice nvarchar(4), @FileID int, @Path nvarchar(4000), @HeaderJson nvarchar(max), @Sql nvarchar(max),
		@DatabaseID int, @Continue bit, @SourceName sysname, @State tinyint, @IsStandby bit;
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

	create table #RestoreFiles
	(
		FileID int identity(1,1) not null primary key, Path nvarchar(4000) collate Latin1_General_100_BIN2 not null,
		FileName nvarchar(4000),
		FileNameWithoutExtension as (left(FileName, len(FileName) - charindex(N'.', reverse(FileName)))),
		Prefix nvarchar(4000), SourceServerName sysname null, SourceInstanceName sysname null, DatabaseName nvarchar(128), Stamp datetime2(7), Kind smallint,
		Inspected bit not null default 0, ReadError nvarchar(2048)
	);
	if @IsFolder = 1
	begin
		insert #RestoreFiles (Path)
			select distinct e.full_filesystem_path
			from sys.dm_os_enumerate_filesystem(@BackupPath, N'*') e
			where e.is_directory = 0;
	end
	else
	begin
		insert #RestoreFiles (Path)
			values (@BackupPath);
	end
	if not exists(select * from #RestoreFiles)
		throw 50000, 'No backup files were found.', 1;
	update #RestoreFiles set FileName = right(replace(Path, N'\', N'/'), charindex(N'/', reverse(replace(Path, N'\', N'/')) + N'/') - 1);
	update f set Prefix = n.Prefix, SourceServerName = n.SourceServerName, SourceInstanceName = n.SourceInstanceName,
		DatabaseName = n.DatabaseName, Stamp = n.BackupTime, Kind = n.BackupType
	from #RestoreFiles f cross apply z.fn_DecodeBackupFileName(f.FileName) n;

	create table #RestoreBackups
	(
		BackupID int identity(1,1) not null, FileID int not null, Position int not null, BackupType smallint not null, DatabaseName sysname null,
		FamilyGUID uniqueidentifier, FirstFork uniqueidentifier, LastFork uniqueidentifier, ForkPointLSN numeric(25,0), FirstLSN numeric(25,0),
		LastLSN numeric(25,0), BackupFinishDate datetime, BackupSetGUID uniqueidentifier, SoftwareVersionMajor int, IsDamaged bit,
		IsSnapshot bit, HasIncompleteMetaData bit, CheckpointLSN numeric(25,0), DifferentialBaseLSN numeric(25,0), DifferentialBaseGUID uniqueidentifier, IsCopyOnly bit, IsEligible bit not null default 0,
		primary key(FileID, BackupID)
	);

	declare @Automatic bit = iif(@TargetDatabaseName is null, 1, 0), @Outcome varchar(20), @ReachedLSN numeric(25,0),
		@TargetName sysname, @SourceFamily uniqueidentifier, @EligibleSources int, @AliasTargets int;
	create table #RestorePlannedPaths (DatabaseName sysname not null, Path nvarchar(4000) collate Latin1_General_100_BIN2 not null);
	create table #RestorePlan
	(
		Ordinal int not null, DatabaseName sysname not null, IsContinuation bit not null, BackupType varchar(10) not null,
		BackupFile nvarchar(4000), Position int, FirstLSN numeric(25,0), LastLSN numeric(25,0), Command nvarchar(max) not null,
		primary key(DatabaseName, Ordinal)
	);
	create table #RestoreTargetState
	(
		DatabaseName sysname not null primary key, FamilyGUID uniqueidentifier, InitialDatabaseID int, InitialState tinyint,
		InitialStandby bit, InitialCreateDate datetime, RecoveryType varchar(10), StandbyFile nvarchar(4000)
	);
	create table #RestoreFileMap
	(
		DatabaseName sysname not null, FileID bigint not null, UniqueID uniqueidentifier,
		DestinationPath nvarchar(4000) collate Latin1_General_100_BIN2, AddedOrdinal int, primary key(DatabaseName, FileID)
	);
	create table #Outcomes
	(
		OutcomeID int identity(1,1) not null primary key, DatabaseName sysname null, SourceDatabaseName sysname null, SourceFamilyGUID uniqueidentifier,
		Status varchar(20) not null, LastLSN numeric(25,0), ErrorNumber int, ErrorMessage nvarchar(2048), BackupPath nvarchar(4000) collate Latin1_General_100_BIN2
	);
	create table #InventoryLabel
	(
		MediaName nvarchar(128), MediaSetId uniqueidentifier, FamilyCount int, FamilySequenceNumber int,
		MediaFamilyId uniqueidentifier, MediaSequenceNumber int, MediaLabelPresent tinyint, MediaDescription nvarchar(255),
		SoftwareName nvarchar(128), SoftwareVendorId int, MediaDate datetime, Mirror_Count int, IsCompressed bit
	);
	-- Convention names are trusted for source grouping and chronological file order.
	-- A header read inventories every appended set, once; unrecognized names are read last.
	create table #DiscoveryGroups (GroupID int identity not null primary key, Prefix nvarchar(4000), Processed bit not null default 0);
	insert #DiscoveryGroups (Prefix) select distinct Prefix from #RestoreFiles where Prefix is not null;
	insert #DiscoveryGroups (Prefix) select null where exists(select * from #RestoreFiles where Prefix is null);
	create table #DiscoverySources
	(
		FamilyGUID uniqueidentifier not null primary key, DatabaseName sysname, Fork uniqueidentifier, EndLSN numeric(25,0),
		NativeLSN numeric(25,0), NativeFork uniqueidentifier, NativeBaseGUID uniqueidentifier, NativeBaseLSN numeric(25,0), SkipSource bit not null default 0
	);
	create table #DiscoveryRoutes
	(
		RouteID int identity not null primary key, FamilyGUID uniqueidentifier, Fork uniqueidentifier, ReachedLSN numeric(25,0),
		BaseGUID uniqueidentifier, BaseLSN numeric(25,0), CanDiff bit not null, Processed bit not null default 0
	);
	declare @GroupID int, @GroupPrefix nvarchar(4000), @DiscoveryRoute int, @DiscoveryLSN numeric(25,0), @DiscoveryEnd numeric(25,0),
		@DiscoveryFamily uniqueidentifier, @DiscoveryFork uniqueidentifier, @DiscoveryPass bit = 0;
	while exists(select * from #DiscoveryGroups where Processed = 0) or @DiscoveryPass = 0
	begin
		if not exists(select * from #DiscoveryGroups where Processed = 0)
		begin
			-- Unknown filenames can extend a previously complete source or introduce a different differential base.
			select @DiscoveryPass = 1;
			update #DiscoveryGroups set Processed = 0 where Prefix is not null;
			if @@rowcount = 0 break;
		end
		select top (1) @GroupID = GroupID, @GroupPrefix = Prefix from #DiscoveryGroups where Processed = 0 order by iif(Prefix is null, 1, 0), Prefix;
		update #DiscoveryGroups set Processed = 1 where GroupID = @GroupID;
		while 1 = 1
		begin
			truncate table #DiscoverySources;
			;with s as
			(
				select b.*, row_number() over(partition by b.FamilyGUID order by b.BackupFinishDate desc, b.Position desc) RowNumber
				from #RestoreBackups b join #RestoreFiles f on f.FileID = b.FileID where b.IsEligible = 1 and exists(select * from #RestoreBackups g join #RestoreFiles gf on gf.FileID = g.FileID where gf.Prefix = @GroupPrefix and g.FamilyGUID = b.FamilyGUID)
			)
			insert #DiscoverySources (FamilyGUID, DatabaseName, Fork)
				select FamilyGUID, DatabaseName, LastFork from s where RowNumber = 1;
			-- A continuation boundary belongs to its native family, never to a filename label alone.
			update s set NativeLSN = n.RedoLSN, NativeFork = r.recovery_fork_guid,
				NativeBaseGUID = n.BaseGUID, NativeBaseLSN = n.BaseLSN,
				SkipSource = iif(@Automatic = 1 and d.database_id is not null and d.state <> 1 and d.is_in_standby = 0, 1, 0)
			from #DiscoverySources s
				left join sys.databases d on d.name = coalesce(@TargetDatabaseName, s.DatabaseName)
				left join sys.database_recovery_status r on r.database_id = d.database_id and r.family_guid = s.FamilyGUID and (d.state = 1 or d.is_in_standby = 1)
				outer apply
				(
					select min(f.redo_start_lsn) RedoLSN, max(iif(f.file_id = 1, f.differential_base_guid, null)) BaseGUID,
						max(iif(f.file_id = 1, f.differential_base_lsn, null)) BaseLSN
					from sys.master_files f where f.database_id = r.database_id and f.type = 0
				) n;
			-- STANDBY can lack native redo metadata; use only the latest compatible unrecovered restore.
			update s set NativeLSN = h.last_lsn
			from #DiscoverySources s
				join sys.databases d on d.name = coalesce(@TargetDatabaseName, s.DatabaseName) and d.is_in_standby = 1
				cross apply
				(
					select top (1) b.last_lsn, b.family_guid, b.last_recovery_fork_guid, b.type, r.*
					from msdb.dbo.restorehistory r join msdb.dbo.backupset b on b.backup_set_id = r.backup_set_id
					where r.destination_database_name = d.name order by r.restore_history_id desc
				) h
			where s.NativeLSN is null and h.family_guid = s.FamilyGUID and h.last_recovery_fork_guid = s.NativeFork
				and h.restore_type in ('D', 'I', 'L') and h.recovery = 0 and h.stop_at is null and h.stop_at_mark_name is null
				and isnull(h.stop_before, 0) = 0 and h.restore_date is not null and (h.type = 'D' or h.restore_date >= d.create_date);
			update s set Fork = coalesce(s.NativeFork, a.LastFork, s.Fork) from #DiscoverySources s
				outer apply
				(
					select top (1) b.LastFork from #RestoreBackups b join #RestoreFiles f on f.FileID = b.FileID
					where b.FamilyGUID = s.FamilyGUID and b.BackupType = 1 and b.IsEligible = 1
					order by b.BackupFinishDate desc, b.Position desc
				) a;
			update s set EndLSN = a.EndLSN from #DiscoverySources s cross apply
				(select max(b.LastLSN) EndLSN from #RestoreBackups b join #RestoreFiles f on f.FileID = b.FileID
				 where b.FamilyGUID = s.FamilyGUID and b.LastFork = s.Fork and b.IsEligible = 1) a;
			truncate table #DiscoveryRoutes;
			insert #DiscoveryRoutes (FamilyGUID, Fork, ReachedLSN, BaseGUID, BaseLSN, CanDiff)
				select b.FamilyGUID, b.LastFork, b.LastLSN, b.BackupSetGUID, b.CheckpointLSN, iif(b.IsCopyOnly = 0, 1, 0)
				from #RestoreBackups b join #RestoreFiles f on f.FileID = b.FileID join #DiscoverySources s on s.FamilyGUID = b.FamilyGUID and s.Fork = b.LastFork
				where b.BackupType = 1 and b.IsEligible = 1 and s.NativeFork is null;
			insert #DiscoveryRoutes (FamilyGUID, Fork, ReachedLSN, BaseGUID, BaseLSN, CanDiff)
				select s.FamilyGUID, s.NativeFork, s.NativeLSN, b.BackupSetGUID, b.CheckpointLSN, iif(b.IsCopyOnly = 0, 1, 0)
				from #DiscoverySources s outer apply
				(
					select top (1) b.* from #RestoreBackups b where b.FamilyGUID = s.FamilyGUID and b.BackupType = 1 and b.IsEligible = 1
						and b.LastFork = s.NativeFork and b.LastLSN = s.NativeLSN and b.BackupSetGUID = s.NativeBaseGUID and b.CheckpointLSN = s.NativeBaseLSN
					order by b.BackupFinishDate desc, b.Position desc
				) b where s.NativeLSN is not null and s.NativeFork is not null;
			-- Keep full/log and full/differential/log alternatives separate; never apply a differential after a log.
			insert #DiscoveryRoutes (FamilyGUID, Fork, ReachedLSN, CanDiff)
				select r.FamilyGUID, r.Fork, b.LastLSN, 0 from #DiscoveryRoutes r join #RestoreBackups b
					on b.FamilyGUID = r.FamilyGUID and b.FirstFork = r.Fork and b.LastFork = r.Fork and b.DifferentialBaseGUID = r.BaseGUID and b.DifferentialBaseLSN = r.BaseLSN
				where r.CanDiff = 1 and b.BackupType = 5 and b.IsEligible = 1 and b.LastLSN > r.ReachedLSN;
			while exists(select * from #DiscoveryRoutes where Processed = 0)
			begin
				select top (1) @DiscoveryRoute = RouteID, @DiscoveryFamily = FamilyGUID, @DiscoveryFork = Fork, @DiscoveryLSN = ReachedLSN from #DiscoveryRoutes where Processed = 0 order by RouteID;
				while 1 = 1
				begin
					select @DiscoveryEnd = max(LastLSN) from #RestoreBackups where FamilyGUID = @DiscoveryFamily and IsEligible = 1 and BackupType = 2
						and FirstFork = @DiscoveryFork and LastFork = @DiscoveryFork and FirstLSN <= @DiscoveryLSN and LastLSN > @DiscoveryLSN;
					if @DiscoveryEnd is null break;
					select @DiscoveryLSN = @DiscoveryEnd;
				end
				update #DiscoveryRoutes set ReachedLSN = @DiscoveryLSN, Processed = 1 where RouteID = @DiscoveryRoute;
			end
			if exists(select * from #DiscoverySources) and not exists
			(
				select * from #DiscoverySources s where s.SkipSource = 0 and not exists
					(select * from #DiscoveryRoutes r where r.FamilyGUID = s.FamilyGUID and r.Fork = s.Fork and r.ReachedLSN >= s.EndLSN)
			) and @GroupPrefix is not null break;
			select @FileID = null;
			select top (1) @FileID = FileID, @Path = Path from #RestoreFiles
			where Inspected = 0 and (Prefix = @GroupPrefix or (Prefix is null and @GroupPrefix is null)) order by Stamp desc, Path desc;
			if @FileID is null break;
			begin try
				select @HeaderJson = null;
				exec z.usp_ReadBackupHeader @BackupFile = @Path, @HeaderJson = @HeaderJson output, @ReturnResult = 0;
				insert #RestoreBackups (FileID, Position, BackupType, DatabaseName, FamilyGUID, FirstFork, LastFork, ForkPointLSN, FirstLSN, LastLSN,
					BackupFinishDate, BackupSetGUID, SoftwareVersionMajor, IsDamaged, IsSnapshot, HasIncompleteMetaData, CheckpointLSN, DifferentialBaseLSN, DifferentialBaseGUID, IsCopyOnly)
					select @FileID, Position, BackupType, DatabaseName, FamilyGUID, FirstRecoveryForkID, RecoveryForkID, ForkPointLSN, FirstLSN, LastLSN,
						BackupFinishDate, BackupSetGUID, SoftwareVersionMajor, IsDamaged, IsSnapshot, HasIncompleteMetaData, CheckpointLSN, DifferentialBaseLSN, DifferentialBaseGUID, IsCopyOnly
					from z.fn_DecodeBackupHeader(@HeaderJson);
				if not exists(select * from #RestoreBackups where FileID = @FileID)
					throw 50000, 'The input file contains no readable backup sets.', 1;
				truncate table #InventoryLabel;
				select @Sql = N'restore labelonly from ' + @BackupDevice + N' = N''' + replace(@Path, N'''', N'''''') + N''';';
				insert #InventoryLabel exec(@Sql);
				if (select count(*) from #InventoryLabel) <> 1 or exists(select * from #InventoryLabel where FamilyCount <> 1 or FamilyCount is null or FamilySequenceNumber <> 1)
					throw 50000, 'Striped or ambiguous media is unsupported; complete single-file media is required.', 1;
				update #RestoreBackups set IsEligible = 1 where FileID = @FileID and BackupType in (1, 2, 5)
					and DatabaseName is not null and FamilyGUID is not null and BackupFinishDate is not null and BackupSetGUID is not null
					and FirstLSN is not null and LastLSN is not null and FirstLSN < LastLSN and FirstFork is not null and LastFork = FirstFork and ForkPointLSN is null
					and isnull(IsDamaged, 1) = 0 and isnull(IsSnapshot, 1) = 0 and isnull(HasIncompleteMetaData, 1) = 0;
				if exists(select * from #RestoreBackups where FileID = @FileID and IsEligible = 0)
					insert #Outcomes (Status, ErrorMessage, BackupPath) values ('Ignored', N'Unsupported or invalid backup sets were excluded from source and endpoint selection.', @Path);
			end try
			begin catch
				update #RestoreBackups set IsEligible = 0 where FileID = @FileID;
				update #RestoreFiles set ReadError = error_message() where FileID = @FileID;
				insert #Outcomes (Status, ErrorNumber, ErrorMessage, BackupPath) values ('Failed', error_number(), error_message(), @Path);
			end catch
			update #RestoreFiles set Inspected = 1 where FileID = @FileID;
		end
	end
	create table #Sources (FamilyGUID uniqueidentifier not null primary key, DatabaseName sysname not null, HasFull bit not null, Processed bit not null default 0);
	;with s as
	(
		select FamilyGUID, DatabaseName, row_number() over (partition by FamilyGUID order by BackupFinishDate desc, BackupSetGUID, DatabaseName, Position desc) RowNumber
		from #RestoreBackups where IsEligible = 1
	)
	insert #Sources (FamilyGUID, DatabaseName, HasFull)
		select s.FamilyGUID, s.DatabaseName, convert(bit, iif(exists(select * from #RestoreBackups b where b.FamilyGUID = s.FamilyGUID and b.BackupType = 1 and b.IsEligible = 1), 1, 0)) from s where RowNumber = 1;
	insert #Outcomes (SourceDatabaseName, SourceFamilyGUID, Status, ErrorMessage)
		select DatabaseName, FamilyGUID, 'Skipped', N'System database sources are excluded.' from #Sources
		where DatabaseName collate Latin1_General_100_CI_AS in (N'master', N'model', N'msdb', N'tempdb');
	delete from #Sources where DatabaseName collate Latin1_General_100_CI_AS in (N'master', N'model', N'msdb', N'tempdb');
	if @Automatic = 0
	begin
		if @TargetDatabaseName collate Latin1_General_100_CI_AS in (N'master', N'model', N'msdb', N'tempdb') or db_id(@TargetDatabaseName) <= 4 or @TargetDatabaseName = db_name()
			throw 50000, 'System databases and the database hosting this procedure cannot be restore targets.', 1;
		select @DatabaseID = db_id(@TargetDatabaseName), @Continue = 0;
		select @Continue = iif(state = 1 or is_in_standby = 1, 1, 0) from sys.databases where database_id = @DatabaseID;
		if @Continue = 1 select @SourceFamily = family_guid from sys.database_recovery_status where database_id = @DatabaseID;
		if @Continue = 0 or @SourceFamily is null
		begin
			if exists(select * from #Outcomes o where o.Status = 'Failed' and not exists
				(select * from #RestoreBackups b join #RestoreFiles f on f.FileID = b.FileID where f.Path = o.BackupPath))
				throw 50000, 'Unreadable backup identity prevents proving an unambiguous initialization source.', 1;
			select @EligibleSources = count(*) from #Sources where HasFull = 1;
			if @EligibleSources > 1 throw 50000, 'Multiple restorable source database families are ambiguous for the requested destination.', 1;
			if @EligibleSources = 0 throw 50000, 'A usable full backup is required to initialize or replace the destination.', 1;
			select @SourceFamily = FamilyGUID from #Sources where HasFull = 1;
		end
		if not exists(select * from #Sources where FamilyGUID = @SourceFamily)
			throw 50000, 'No available backup source matches the destination database family.', 1;
		-- Known foreign media failures do not invalidate the selected source; unknown identities stay visible.
		update o set Status = 'Ignored' from #Outcomes o
		where o.Status = 'Failed' and exists(select * from #RestoreBackups b join #RestoreFiles f on f.FileID = b.FileID where f.Path = o.BackupPath)
			and not exists(select * from #RestoreBackups b join #RestoreFiles f on f.FileID = b.FileID where f.Path = o.BackupPath and b.FamilyGUID = @SourceFamily);
		select @SourceName = DatabaseName from #Sources where FamilyGUID = @SourceFamily;
		exec z.usp_RestoreDatabaseTarget @BackupPath = @BackupPath, @TargetDatabaseName = @TargetDatabaseName,
			@RecoveryType = @RecoveryType, @ReplaceExisting = @ReplaceExisting, @OtherRestoreOptions = @OtherRestoreOptions,
			@DataFolder = @DataFolder, @LogFolder = @LogFolder, @StandbyFolder = @StandbyFolder,
			@UseDefaultFolder = @UseDefaultFolder, @ShowPlan = @ShowPlan, @DropConnections = @DropConnections,
			@SourceFamilyGUID = @SourceFamily, @Automatic = 0, @Outcome = @Outcome output, @ReachedLSN = @ReachedLSN output;
		insert #Outcomes (DatabaseName, SourceDatabaseName, SourceFamilyGUID, Status, LastLSN) values (@TargetDatabaseName, @SourceName, @SourceFamily, @Outcome, @ReachedLSN);
	end
	else
	begin
		while exists(select * from #Sources where Processed = 0)
		begin
			select top (1) @SourceFamily = FamilyGUID, @TargetName = DatabaseName, @SourceName = DatabaseName, @Outcome = null, @ReachedLSN = null from #Sources where Processed = 0 order by DatabaseName, FamilyGUID;
			update #Sources set Processed = 1 where FamilyGUID = @SourceFamily;
			begin try
				if (select count(*) from #Sources where DatabaseName = @TargetName) > 1
					throw 50000, 'Different source families share a destination database name; automatic restore is ambiguous.', 1;
				-- Reuse a unique existing source-name alias after a source rename; never invent a second secondary.
				select @AliasTargets = count(*) from sys.databases d join sys.database_recovery_status r on r.database_id = d.database_id
				where r.family_guid = @SourceFamily and (d.state = 1 or d.is_in_standby = 1)
					and exists(select * from #RestoreBackups b where b.FamilyGUID = @SourceFamily and b.DatabaseName = d.name);
				if @AliasTargets > 1 throw 50000, 'Several source-name aliases already have continuation targets for this family.', 1;
				if @AliasTargets = 0 and db_id(@TargetName) is null and exists
					(select * from sys.databases d join sys.database_recovery_status r on r.database_id = d.database_id
					where r.family_guid = @SourceFamily and (d.state = 1 or d.is_in_standby = 1))
					throw 50000, 'A same-family continuation target exists outside the known source names; specify its destination explicitly.', 1;
				if @AliasTargets = 1
					select @TargetName = d.name from sys.databases d join sys.database_recovery_status r on r.database_id = d.database_id
					where r.family_guid = @SourceFamily and (d.state = 1 or d.is_in_standby = 1)
						and exists(select * from #RestoreBackups b where b.FamilyGUID = @SourceFamily and b.DatabaseName = d.name);
				select @DatabaseID = db_id(@TargetName), @State = null, @IsStandby = 0;
				select @State = state, @IsStandby = is_in_standby from sys.databases where database_id = @DatabaseID;
				if @TargetName = db_name() or @DatabaseID <= 4
					insert #Outcomes (DatabaseName, SourceDatabaseName, SourceFamilyGUID, Status, ErrorMessage) values (@TargetName, @SourceName, @SourceFamily, 'Skipped', N'The database hosting this procedure and system targets are excluded.');
				else if @DatabaseID is not null and isnull(@State, -1) <> 1 and @IsStandby = 0
					insert #Outcomes (DatabaseName, SourceDatabaseName, SourceFamilyGUID, Status, ErrorMessage) values (@TargetName, @SourceName, @SourceFamily, 'Skipped', N'Automatic restore does not replace ONLINE or unavailable destinations.');
				else if @DatabaseID is null and exists(select * from #Sources where FamilyGUID = @SourceFamily and HasFull = 0)
					insert #Outcomes (DatabaseName, SourceDatabaseName, SourceFamilyGUID, Status, ErrorMessage) values (@TargetName, @SourceName, @SourceFamily, 'Deferred', N'A full backup is needed to initialize this database.');
				else
				begin
					exec z.usp_RestoreDatabaseTarget @BackupPath = @BackupPath, @TargetDatabaseName = @TargetName,
						@RecoveryType = @RecoveryType, @ReplaceExisting = 0, @OtherRestoreOptions = @OtherRestoreOptions,
						@DataFolder = @DataFolder, @LogFolder = @LogFolder, @StandbyFolder = @StandbyFolder,
						@UseDefaultFolder = @UseDefaultFolder, @ShowPlan = @ShowPlan, @DropConnections = @DropConnections,
						@SourceFamilyGUID = @SourceFamily, @Automatic = 1, @Outcome = @Outcome output, @ReachedLSN = @ReachedLSN output;
					insert #Outcomes (DatabaseName, SourceDatabaseName, SourceFamilyGUID, Status, LastLSN) values (@TargetName, @SourceName, @SourceFamily, @Outcome, @ReachedLSN);
				end
			end try
			begin catch
				delete #RestorePlan where DatabaseName = @TargetName;
				delete #RestoreTargetState where DatabaseName = @TargetName;
				delete #RestoreFileMap where DatabaseName = @TargetName;
				delete #RestorePlannedPaths where DatabaseName = @TargetName;
				insert #Outcomes (DatabaseName, SourceDatabaseName, SourceFamilyGUID, Status, ErrorNumber, ErrorMessage) values (@TargetName, @SourceName, @SourceFamily, 'Failed', error_number(), error_message());
			end catch
		end
	end
	if not exists(select * from #Sources) and not exists(select * from #Outcomes where Status in ('Skipped', 'Failed'))
		insert #Outcomes (Status, ErrorNumber, ErrorMessage) values ('Failed', 50000, N'No eligible database backup sources were found.');
	-- All discovery, file mapping and command generation finish before any destination is changed.
	if @ShowPlan = 0
	begin
		declare @ExecutionOutcomeID int;
		declare cExecuteTargets cursor local fast_forward for
			select o.OutcomeID, o.DatabaseName from #Outcomes o join #RestoreTargetState s on s.DatabaseName = o.DatabaseName
			where o.Status in ('Initialized', 'Advanced', 'AlreadyCurrent') order by o.OutcomeID;
		open cExecuteTargets;
		fetch next from cExecuteTargets into @ExecutionOutcomeID, @TargetName;
		while @@fetch_status = 0
		begin
			begin try
				exec z.usp_RestoreDatabaseExecute @TargetDatabaseName = @TargetName;
			end try
			begin catch
				update #Outcomes set Status = 'Failed', LastLSN = null, ErrorNumber = error_number(), ErrorMessage = error_message() where OutcomeID = @ExecutionOutcomeID;
				if @Automatic = 0 throw;
			end catch
			fetch next from cExecuteTargets into @ExecutionOutcomeID, @TargetName;
		end
		close cExecuteTargets;
		deallocate cExecuteTargets;
	end
	select DatabaseName, SourceDatabaseName, SourceFamilyGUID, Status, LastLSN, ErrorNumber, ErrorMessage, BackupPath from #Outcomes order by OutcomeID;
	if @ShowPlan = 0 and exists(select * from #Outcomes where Status = 'Failed')
		throw 50000, 'One or more backup sources failed; inspect the per-database restore outcomes.', 1;
end
