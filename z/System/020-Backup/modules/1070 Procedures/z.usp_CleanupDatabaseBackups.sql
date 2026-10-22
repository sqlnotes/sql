create or alter procedure z.usp_CleanupDatabaseBackups
(
	@DatabaseName sysname,
	@DatabaseBackupFolder nvarchar(max),
	@RetentionHours int,
	@ShowPlan bit = 0,
	@UseBackupHeader bit = 0
)
as
begin
	set nocount on;
	set xact_abort off;
	-- Filesystem operations are not transactional; never roll back a caller's work.
	if @@trancount <> 0 throw 50000, 'Backup cleanup cannot run inside a transaction.', 1;
	set xact_abort on;
	if @RetentionHours is null return;
	if @RetentionHours <= 0 throw 50000, '@RetentionHours must be positive or NULL (disabled).', 1;
	if datalength(@DatabaseBackupFolder) > 8000
		throw 50000, 'Backup path exceeds 4000 characters.', 1;
	if @ShowPlan is null or @UseBackupHeader is null throw 50000, '@ShowPlan and @UseBackupHeader must be 0 or 1.', 1;

	declare @Platform nvarchar(256), @Separator nchar(1), @Root nvarchar(4000), @Folder nvarchar(4000),
		@Path nvarchar(4000), @Sql nvarchar(max), @LockName nvarchar(255), @LockResult int, @DeleteResult int,
		@Family uniqueidentifier, @Fork uniqueidentifier, @Major int,
		@Cutoff datetime2(6), @Now datetime2(6) = sysdatetime(), @AnchorStart datetime2(6), @AnchorFirstLSN numeric(25,0),
		@Prefix nvarchar(128), @PredecessorLog datetime2(6),
		@SkipReason nvarchar(2048), @Pass int = 1, @Fingerprint varbinary(32), @ExpectedFingerprint varbinary(32),
		@LockHeld bit = 0, @TypeFolder nvarchar(4), @Character int = 1, @LongestPath int;
	select @Platform = host_platform from sys.dm_os_host_info;
	if @Platform not in (N'Windows', N'Linux') or @Platform is null throw 50000, 'Unsupported backup filesystem platform.', 1;
	select @Separator = iif(@Platform = N'Linux', N'/', N'\'), @Root = @DatabaseBackupFolder;
	if @Root is null or len(@Root) = 0 or datalength(@Root) <> datalength(rtrim(@Root))
		throw 50000, 'An absolute database backup folder without trailing spaces is required.', 1;
	if @Root like N'%[*?]%' or exists(select * from string_split(replace(@Root, N'\', N'/'), N'/') where value in (N'.', N'..'))
		throw 50000, 'Backup folder cannot contain wildcard or dot path segments.', 1;
	while @Character <= datalength(@Root) / 2
	begin
		if unicode(substring(@Root, @Character, 1)) < 32 throw 50000, 'Backup folder cannot contain control characters.', 1;
		select @Character += 1;
	end
	if (@Platform = N'Linux' and charindex(N'//', @Root) > 0)
		or (@Platform = N'Windows' and (charindex(N'\\', substring(@Root, 3, len(@Root))) > 0
			or charindex(N':', substring(@Root, 3, len(@Root))) > 0
			or exists(select * from string_split(@Root, N'\') where right(value, 1) in (N'.', N' '))))
		throw 50000, 'Backup folder contains ambiguous separators or Windows path aliases.', 1;
	if @Platform = N'Linux' and (left(@Root, 1) <> N'/' or charindex(N'\', @Root) > 0)
		throw 50000, 'Linux backup folders must be absolute mounted filesystem paths.', 1;
	if @Platform = N'Windows' and (charindex(N'/', @Root) > 0 or not
		(left(@Root, 3) like N'[A-Za-z]:\' or (left(@Root, 2) = N'\\' and charindex(N'\', @Root, 3) > 3
		and len(@Root) > charindex(N'\', @Root, 3))))
		throw 50000, 'Windows backup folders must be absolute drive or UNC paths.', 1;
	while right(@Root, 1) = @Separator and len(@Root) > 1 select @Root = left(@Root, len(@Root) - 1);
	if len(@Root) + 5 > 4000 throw 50000, 'Database backup folder is too long.', 1;
	if @RetentionHours > datediff(hour, convert(datetime2(6), '00010101', 112), @Now)
		throw 50000, '@RetentionHours exceeds the supported datetime range.', 1;
	if not exists(select * from sys.dm_os_file_exists(@Root) where file_is_a_directory = 1)
		throw 50000, 'Database backup root is missing or inaccessible.', 1;
	select @Cutoff = dateadd(hour, -@RetentionHours, @Now);
	if db_id(@DatabaseName) is null throw 50000, 'Database does not exist; cleanup refused.', 1;
	select @Prefix = replace(translate(@DatabaseName, N'<>:"/\?*', N'        '), N' ', N'_');
	select @LockName = N'z.Backup:' + convert(nvarchar(64), hashbytes('SHA2_256', convert(varbinary(max),
		convert(nvarchar(max), convert(nvarchar(20), db_id(@DatabaseName))) + N'|' + iif(@Platform = N'Windows', lower(@Root), @Root))), 2);

	create table #Files
	(
		Path nvarchar(4000) collate Latin1_General_100_BIN2 not null,
		FileName nvarchar(4000), FolderType nvarchar(4), LastWriteTime datetime2(7), SizeInBytes bigint,
		BackupType smallint, BackupStartDate datetime2(6), BackupFinishDate datetime2(6),
		FirstLSN numeric(25,0), LastLSN numeric(25,0), CheckpointLSN numeric(25,0),
		DifferentialBaseLSN numeric(25,0), DifferentialBaseGUID uniqueidentifier, BackupSetGUID uniqueidentifier,
		IsCopyOnly bit, Fingerprint varbinary(32), Action nvarchar(10) not null default N'KEEP', Reason nvarchar(2048)
	);
	if @UseBackupHeader = 1
	begin
		select @Major = try_convert(int, serverproperty('ProductMajorVersion'));
		if @Major not in (15, 16, 17) or @Major is null throw 50000, 'Unsupported RESTORE HEADERONLY result version; cleanup refused.', 1;
		select @Family = family_guid, @Fork = recovery_fork_guid from sys.database_recovery_status where database_id = db_id(@DatabaseName);
		if @Family is null or @Fork is null throw 50000, 'Database recovery identity is unavailable; cleanup refused.', 1;
		create table #Header
		(
			BackupName nvarchar(128), BackupDescription nvarchar(255), BackupType smallint, ExpirationDate datetime,
			Compressed bit, Position smallint, DeviceType tinyint, UserName nvarchar(128), ServerName nvarchar(128), DatabaseName nvarchar(128),
			DatabaseVersion int, DatabaseCreationDate datetime, BackupSize numeric(20,0), FirstLSN numeric(25,0), LastLSN numeric(25,0),
			CheckpointLSN numeric(25,0), DatabaseBackupLSN numeric(25,0), BackupStartDate datetime, BackupFinishDate datetime,
			SortOrder smallint, CodePage smallint, UnicodeLocaleId int, UnicodeComparisonStyle int, CompatibilityLevel tinyint,
			SoftwareVendorId int, SoftwareVersionMajor int, SoftwareVersionMinor int, SoftwareVersionBuild int, MachineName nvarchar(128),
			Flags int, BindingID uniqueidentifier, RecoveryForkID uniqueidentifier, Collation nvarchar(128), FamilyGUID uniqueidentifier,
			HasBulkLoggedData bit, IsSnapshot bit, IsReadOnly bit, IsSingleUser bit, HasBackupChecksums bit, IsDamaged bit,
			BeginsLogChain bit, HasIncompleteMetaData bit, IsForceOffline bit, IsCopyOnly bit, FirstRecoveryForkID uniqueidentifier,
			ForkPointLSN numeric(25,0), RecoveryModel nvarchar(60), DifferentialBaseLSN numeric(25,0), DifferentialBaseGUID uniqueidentifier,
			BackupTypeDescription nvarchar(60), BackupSetGUID uniqueidentifier, CompressedBackupSize numeric(20,0), Containment tinyint,
			KeyAlgorithm nvarchar(32), EncryptorThumbprint varbinary(20), EncryptorType nvarchar(32)
		);
		-- SQL Server 2022 and 2025 append three columns; 2019 has the preceding 56.
		if @Major in (16, 17) exec(N'alter table #Header add LastValidRestoreTime datetime, TimeZone nvarchar(32), CompressionAlgorithm nvarchar(32);');
		create table #Label
		(
			MediaName nvarchar(128), MediaSetId uniqueidentifier, FamilyCount int, FamilySequenceNumber int,
			MediaFamilyId uniqueidentifier, MediaSequenceNumber int, MediaLabelPresent tinyint, MediaDescription nvarchar(255),
			SoftwareName nvarchar(128), SoftwareVendorId int, MediaDate datetime, MirrorCount int, IsCompressed bit
		);
	end
	begin try
		exec @LockResult = sys.sp_getapplock @Resource = @LockName, @LockMode = 'Exclusive', @LockOwner = 'Session', @LockTimeout = 0, @DbPrincipal = 'public';
		if @LockResult < 0 throw 50000, 'A backup or cleanup is already active for this database folder.', 1;
		select @LockHeld = 1;
		declare Folders cursor local fast_forward for select Name from (values(N'FULL'),(N'DIFF'),(N'LOG')) f(Name);
		open Folders;
		fetch next from Folders into @TypeFolder;
		while @@fetch_status = 0
		begin
			select @Folder = @Root + @Separator + @TypeFolder;
			if not exists(select * from sys.dm_os_file_exists(@Folder) where file_is_a_directory = 1) and exists
				(select * from sys.dm_os_enumerate_filesystem(@Root, N'*') where is_directory = 1
					and ((@Platform = N'Linux' and full_filesystem_path collate Latin1_General_100_BIN2 = @Folder collate Latin1_General_100_BIN2)
					or (@Platform = N'Windows' and full_filesystem_path collate Latin1_General_100_CI_AS = @Folder collate Latin1_General_100_CI_AS)))
				throw 50000, 'A managed backup directory is inaccessible; cleanup refused.', 1;
			if exists(select * from sys.dm_os_file_exists(@Folder) where file_is_a_directory = 1)
			begin
				if exists(select * from sys.dm_os_enumerate_filesystem(@Folder, N'*')
					where is_directory = 0 and datalength(full_filesystem_path) > 8000)
					throw 50000, 'Inventory contains an unsupported path length; cleanup refused.', 1;
				insert #Files(Path, FileName, FolderType, LastWriteTime, SizeInBytes)
					select full_filesystem_path, file_or_directory_name, @TypeFolder, last_write_time, size_in_bytes from sys.dm_os_enumerate_filesystem(@Folder, N'*')
					where is_directory = 0 and (lower(right(file_or_directory_name, 4)) in (N'.bak', N'.trn') or lower(right(file_or_directory_name, 5)) = N'.diff')
						and ((@Platform = N'Linux' and (parent_directory collate Latin1_General_100_BIN2 = @Folder collate Latin1_General_100_BIN2
							or parent_directory collate Latin1_General_100_BIN2 = (@Folder + @Separator) collate Latin1_General_100_BIN2)
							and full_filesystem_path collate Latin1_General_100_BIN2 = (@Folder + @Separator + file_or_directory_name) collate Latin1_General_100_BIN2)
						or (@Platform = N'Windows' and (parent_directory collate Latin1_General_100_CI_AS = @Folder collate Latin1_General_100_CI_AS
							or parent_directory collate Latin1_General_100_CI_AS = (@Folder + @Separator) collate Latin1_General_100_CI_AS)
							and full_filesystem_path collate Latin1_General_100_CI_AS = (@Folder + @Separator + file_or_directory_name) collate Latin1_General_100_CI_AS));
			end
			fetch next from Folders into @TypeFolder;
		end
		close Folders;
		deallocate Folders;
		if exists(select Path from #Files group by Path having count(*) > 1) throw 50000, 'Duplicate inventory paths; cleanup refused.', 1;

		if @UseBackupHeader = 1
		begin
			if exists(select * from #Files where datalength(Path) > 518)
				select @SkipReason = N'A backup filename exceeds the native 259-character path limit; no files deleted.';
			if exists(select * from #Files where charindex(N'*', Path) > 0 or charindex(N'?', Path) > 0)
				select @SkipReason = N'A backup filename contains wildcard characters; no files deleted.';
			select @Character = 1, @LongestPath = max(datalength(Path) / 2) from #Files;
			while @Character <= @LongestPath and @SkipReason is null
			begin
				if exists(select * from #Files where @Character <= datalength(Path) / 2 and unicode(substring(Path, @Character, 1)) < 32)
					select @SkipReason = N'A backup filename contains control characters; no files deleted.';
				select @Character += 1;
			end
			while @Pass <= 2 and @SkipReason is null
			begin
				declare Media cursor local fast_forward for select Path, Fingerprint from #Files order by Path;
				open Media;
				fetch next from Media into @Path, @ExpectedFingerprint;
				while @@fetch_status = 0 and @SkipReason is null
				begin
					truncate table #Header;
					truncate table #Label;
					begin try
						select @Sql = N'restore labelonly from disk = N''' + replace(@Path, N'''', N'''''') + N''';';
						insert #Label exec(@Sql);
						select @Sql = N'restore headeronly from disk = N''' + replace(@Path, N'''', N'''''') + N''';';
						insert #Header exec(@Sql);
					end try
					begin catch
						select @SkipReason = N'Unreadable backup media; no files deleted. ' + left(error_message(), 1200);
					end catch;
					if @SkipReason is null and ((select count(*) from #Header) <> 1 or (select count(*) from #Label) <> 1)
						select @SkipReason = N'Multiple or missing backup sets/media labels; no files deleted.';
					if @SkipReason is null and exists(select * from #Label where FamilyCount <> 1 or FamilyCount is null or FamilySequenceNumber <> 1
						or MirrorCount <> 1 or MirrorCount is null or MediaSequenceNumber <> 1 or MediaSetId is null or MediaFamilyId is null)
						select @SkipReason = N'Unsupported striped, mirrored or incomplete media; no files deleted.';
					if @SkipReason is null and exists(select * from #Header where DatabaseName <> @DatabaseName or DatabaseName is null
						or FamilyGUID <> @Family or FamilyGUID is null or RecoveryForkID <> @Fork or RecoveryForkID is null
						or FirstRecoveryForkID <> @Fork or FirstRecoveryForkID is null or ForkPointLSN is not null
						or BackupType not in (1, 2, 5) or BackupType is null or Position <> 1 or DeviceType <> 2
						or IsSnapshot <> 0 or IsSnapshot is null or IsDamaged <> 0 or IsDamaged is null or HasIncompleteMetaData <> 0 or HasIncompleteMetaData is null
						or IsCopyOnly is null or BackupSetGUID is null or BackupStartDate is null or BackupFinishDate is null
						or BackupFinishDate < BackupStartDate or FirstLSN is null or LastLSN is null or FirstLSN >= LastLSN
						or BackupType = 1 and CheckpointLSN is null)
						select @SkipReason = N'Foreign, unsupported or ambiguous backup metadata; no files deleted.';
					if @SkipReason is null
					begin
						select @Fingerprint = hashbytes('SHA2_256', convert(varbinary(max),
							convert(nvarchar(max), (select * from #Header for xml raw, binary base64)) +
							convert(nvarchar(max), (select * from #Label for xml raw, binary base64))));
						if @Pass = 2 and (@Fingerprint <> @ExpectedFingerprint or @Fingerprint is null)
							select @SkipReason = N'Backup media changed since inventory; no files deleted.';
						if @Pass = 1 update f set BackupType = h.BackupType, BackupStartDate = h.BackupStartDate, BackupFinishDate = h.BackupFinishDate,
							FirstLSN = h.FirstLSN, LastLSN = h.LastLSN, CheckpointLSN = h.CheckpointLSN, DifferentialBaseLSN = h.DifferentialBaseLSN,
							DifferentialBaseGUID = h.DifferentialBaseGUID, BackupSetGUID = h.BackupSetGUID, IsCopyOnly = h.IsCopyOnly, Fingerprint = @Fingerprint
							from #Files f cross join #Header h where f.Path = @Path;
					end
					fetch next from Media into @Path, @ExpectedFingerprint;
				end
				close Media;
				deallocate Media;
				if @Pass = 1 and @SkipReason is null
				begin
					select top(1) @AnchorStart = BackupStartDate, @AnchorFirstLSN = FirstLSN from #Files
						where BackupType = 1 and IsCopyOnly = 0 and BackupFinishDate <= @Cutoff order by BackupFinishDate desc, Path;
					if @AnchorStart is null select @SkipReason = N'No ordinary full backup at or before cutoff; no files deleted.';
					else
					begin
						update #Files set Reason = N'Retained anchor, newer backup or overlapping log.';
						update #Files set Action = N'DELETE', Reason = N'Older than cutoff and retained anchor; no retained dependency identified.'
							where BackupFinishDate < @Cutoff and BackupFinishDate < @AnchorStart
								and not (BackupType = 2 and LastLSN > @AnchorFirstLSN);
						if exists(select * from #Files d where d.Action = N'KEEP' and d.BackupType = 5 and not exists
							(select * from #Files f where f.Action = N'KEEP' and f.BackupType = 1 and f.IsCopyOnly = 0
								and f.BackupSetGUID = d.DifferentialBaseGUID and f.CheckpointLSN = d.DifferentialBaseLSN))
							select @SkipReason = N'A retained differential lacks an unambiguous retained full base; no files deleted.';
					end
				end
				select @Pass += 1;
			end
		end
		else
		begin
			if exists(select * from sys.databases d
				cross apply (values(replace(translate(d.name, N'<>:"/\?*', N'        '), N' ', N'_'))) n(Prefix)
				where d.database_id <> db_id(@DatabaseName)
					and ((@Platform = N'Linux' and n.Prefix collate Latin1_General_100_BIN2 = @Prefix collate Latin1_General_100_BIN2)
					or (@Platform = N'Windows' and n.Prefix collate Latin1_General_100_CI_AS = @Prefix collate Latin1_General_100_CI_AS)))
				select @SkipReason = N'Another database maps to the same managed filename prefix; filename cleanup skipped for the whole folder.';
			-- This mode trusts only the exact managed filename convention, not backup contents.
			update #Files set Reason = N'Filename does not match the managed database/type/timestamp convention; preserved.';
			update #Files set Reason = N'Path exceeds the native 259-character limit; preserved.' where datalength(Path) > 518;
			update f set BackupType = t.BackupType, BackupStartDate = p.BackupTime, BackupFinishDate = p.BackupTime,
				Reason = N'Recognized filename; retained at or after the full anchor.'
				from #Files f
					cross apply (values(case f.FolderType when N'FULL' then 1 when N'DIFF' then 5 else 2 end,
						case f.FolderType when N'FULL' then N'.bak' when N'DIFF' then N'.diff' else N'.trn' end)) t(BackupType, Extension)
					cross apply (values(substring(f.FileName, len(@Prefix) + 2, 22))) n(Stamp)
					cross apply (values(try_convert(datetime2(6), substring(n.Stamp, 1, 4) + N'-' + substring(n.Stamp, 5, 2) + N'-' + substring(n.Stamp, 7, 2)
						+ N'T' + substring(n.Stamp, 10, 2) + N':' + substring(n.Stamp, 12, 2) + N':' + substring(n.Stamp, 14, 2)
						+ N'.' + substring(n.Stamp, 17, 6), 126))) p(BackupTime)
				where datalength(f.Path) <= 518 and p.BackupTime is not null
					and datalength(f.FileName) = datalength(@Prefix + N'_' + n.Stamp + t.Extension)
					and f.FileName collate Latin1_General_100_BIN2 = (@Prefix + N'_' + n.Stamp + t.Extension) collate Latin1_General_100_BIN2
					and substring(n.Stamp, 9, 1) = N'_' and substring(n.Stamp, 16, 1) = N'_'
					and datalength(replace(n.Stamp, N'_', N'')) = 40
					and replace(n.Stamp, N'_', N'') collate Latin1_General_100_BIN2 not like N'%[^0-9]%'
					and n.Stamp collate Latin1_General_100_BIN2 = (convert(nvarchar(8), p.BackupTime, 112) + N'_'
						+ replace(convert(nvarchar(8), p.BackupTime, 108), N':', N'') + N'_'
						+ right(N'000000' + convert(nvarchar(6), datepart(microsecond, p.BackupTime)), 6)) collate Latin1_General_100_BIN2;
			select top(1) @AnchorStart = BackupFinishDate from #Files where BackupType = 1 and BackupFinishDate <= @Cutoff
				order by BackupFinishDate desc, Path;
			if @AnchorStart is null and @SkipReason is null select @SkipReason = N'No recognized full filename at or before cutoff; no files deleted.';
			else
			begin
				update #Files set Action = N'DELETE', Reason = N'Filename timestamp is older than the cutoff and retained full anchor.'
					where BackupType is not null and BackupFinishDate < @Cutoff and BackupFinishDate < @AnchorStart;
				select @PredecessorLog = max(BackupFinishDate) from #Files where BackupType = 2 and BackupFinishDate < @AnchorStart;
				update #Files set Action = N'KEEP', Reason = N'Last log filename before the full anchor; conservatively retained.'
					where BackupType = 2 and BackupFinishDate = @PredecessorLog;
			end
		end
		if @SkipReason is null
		begin
			create table #CurrentPaths(Path nvarchar(4000) collate Latin1_General_100_BIN2, LastWriteTime datetime2(7), SizeInBytes bigint);
			declare CurrentFolders cursor local fast_forward for select Name from (values(N'FULL'),(N'DIFF'),(N'LOG')) f(Name);
			open CurrentFolders;
			fetch next from CurrentFolders into @TypeFolder;
			while @@fetch_status = 0
			begin
				select @Folder = @Root + @Separator + @TypeFolder;
				if not exists(select * from sys.dm_os_file_exists(@Folder) where file_is_a_directory = 1) and exists
				(select * from sys.dm_os_enumerate_filesystem(@Root, N'*') where is_directory = 1
					and ((@Platform = N'Linux' and full_filesystem_path collate Latin1_General_100_BIN2 = @Folder collate Latin1_General_100_BIN2)
					or (@Platform = N'Windows' and full_filesystem_path collate Latin1_General_100_CI_AS = @Folder collate Latin1_General_100_CI_AS)))
				throw 50000, 'A managed backup directory is inaccessible; cleanup refused.', 1;
			if exists(select * from sys.dm_os_file_exists(@Folder) where file_is_a_directory = 1)
				begin
					insert #CurrentPaths(Path, LastWriteTime, SizeInBytes)
					select full_filesystem_path, last_write_time, size_in_bytes from sys.dm_os_enumerate_filesystem(@Folder, N'*')
					where is_directory = 0 and (lower(right(file_or_directory_name, 4)) in (N'.bak', N'.trn') or lower(right(file_or_directory_name, 5)) = N'.diff')
						and ((@Platform = N'Linux' and (parent_directory collate Latin1_General_100_BIN2 = @Folder collate Latin1_General_100_BIN2
							or parent_directory collate Latin1_General_100_BIN2 = (@Folder + @Separator) collate Latin1_General_100_BIN2)
							and full_filesystem_path collate Latin1_General_100_BIN2 = (@Folder + @Separator + file_or_directory_name) collate Latin1_General_100_BIN2)
						or (@Platform = N'Windows' and (parent_directory collate Latin1_General_100_CI_AS = @Folder collate Latin1_General_100_CI_AS
							or parent_directory collate Latin1_General_100_CI_AS = (@Folder + @Separator) collate Latin1_General_100_CI_AS)
							and full_filesystem_path collate Latin1_General_100_CI_AS = (@Folder + @Separator + file_or_directory_name) collate Latin1_General_100_CI_AS));
				end
				fetch next from CurrentFolders into @TypeFolder;
			end
			close CurrentFolders;
			deallocate CurrentFolders;
			if exists(select Path, LastWriteTime, SizeInBytes from #CurrentPaths except select Path, LastWriteTime, SizeInBytes from #Files)
				or exists(select Path, LastWriteTime, SizeInBytes from #Files except select Path, LastWriteTime, SizeInBytes from #CurrentPaths)
				select @SkipReason = N'Backup inventory changed before deletion; no files deleted.';
		end
		if @SkipReason is not null
		begin
			update #Files set Action = N'KEEP', Reason = @SkipReason;
			print @SkipReason;
		end
		if @ShowPlan = 0 and @SkipReason is null
		begin
			declare Deletions cursor local fast_forward for select Path from #Files where Action = N'DELETE'
				order by case BackupType when 5 then 1 when 2 then 2 else 3 end, BackupFinishDate, Path;
			open Deletions;
			fetch next from Deletions into @Path;
			while @@fetch_status = 0
			begin
				exec @DeleteResult = master.dbo.xp_delete_file 0, @Path;
				if @DeleteResult <> 0 or @DeleteResult is null or exists(select * from sys.dm_os_file_exists(@Path) where file_exists = 1 or file_is_a_directory = 1)
					throw 50000, 'Exact backup file deletion failed; remaining files were preserved.', 1;
				update #Files set Action = N'DELETED' where Path = @Path;
				fetch next from Deletions into @Path;
			end
			close Deletions;
			deallocate Deletions;
		end
		exec sys.sp_releaseapplock @Resource = @LockName, @LockOwner = 'Session', @DbPrincipal = 'public';
		select @LockHeld = 0;
		if @ShowPlan = 1 select Path, BackupType, BackupFinishDate, Action, Reason from #Files order by Path;
	end try
	begin catch
		if @LockHeld = 1 exec sys.sp_releaseapplock @Resource = @LockName, @LockOwner = 'Session', @DbPrincipal = 'public';
		throw;
	end catch;
end
go
