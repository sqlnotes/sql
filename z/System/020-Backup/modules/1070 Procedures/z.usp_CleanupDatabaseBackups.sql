/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/020-Backup/modules/1070%20Procedures/z.usp_CleanupDatabaseBackups.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/020-Backup/docs/reference/z.usp_CleanupDatabaseBackups.md

Deletes expired backup files under a folder best-effort without throwing T-SQL exceptions, optionally preserving each database's latest recovery chain.
*/
create or alter procedure z.usp_CleanupDatabaseBackups
(
	@BackupFolder nvarchar(4000),
	@RetentionHours int,
	@BackupType varchar(10) = null, -- null/All = all types, or Full, Diff, Log
	@KeepLatestChain bit = 1,
	@UseBackupHeader bit = 0
)
as
begin
	set nocount, xact_abort on;
	if @@trancount > 0 or @@options & 2 = 2
		return;

	declare	@IsLinux bit = z.fn_IsLinux(), @Separator nchar(1), @Root nvarchar(4000),
			@TargetTypeCode smallint, @Now datetime2(7), @Cutoff datetime2(7),
			@Path nvarchar(4000), @HeaderJson nvarchar(max);

	select	@Root = nullif(trim(@BackupFolder), N''),
			@BackupType = upper(nullif(trim(@BackupType), '') collate Latin1_General_100_CI_AS),
			@KeepLatestChain = isnull(@KeepLatestChain, 1),
			@UseBackupHeader = isnull(@UseBackupHeader, 0);

	if @RetentionHours is null or @RetentionHours <= 0 or @Root is null
		return;
	if @BackupType = 'ALL'
		select	@BackupType = null;
	if @BackupType is not null and @BackupType not in ('FULL', 'DIFF', 'LOG')
		return;

	select	@Separator = iif(@IsLinux = 1, N'/', N'\'),
			@TargetTypeCode = case @BackupType when 'FULL' then 1 when 'DIFF' then 5 when 'LOG' then 2 end,
			@Now = iif(@UseBackupHeader = 1, sysdatetime(), sysutcdatetime());

	if @IsLinux = 0
		select	@Root = replace(@Root, N'/', N'\');
	while right(@Root, 1) = @Separator and len(@Root) > 1
		select	@Root = left(@Root, len(@Root) - 1);

	if @RetentionHours > datediff(hour, convert(datetime2(7), '19000101', 112), @Now)
		return;
	select	@Cutoff = dateadd(hour, -@RetentionHours, @Now);

	begin try
		if not exists (select 1 from sys.dm_os_file_exists(@Root) where file_is_a_directory = 1)
			return;
	end try
	begin catch
		return;
	end catch;

	create table #Files (Path nvarchar(4000) collate Latin1_General_100_BIN2 not null primary key, FileName nvarchar(4000) collate Latin1_General_100_BIN2, ContainerFolder nvarchar(4000) collate Latin1_General_100_BIN2, GroupKey nvarchar(4000) collate Latin1_General_100_BIN2, DatabaseName nvarchar(128) collate Latin1_General_100_BIN2, FamilyGUID uniqueidentifier, BackupType smallint, BackupTime datetime2(7), FirstLSN numeric(25,0), LastLSN numeric(25,0), CheckpointLSN numeric(25,0), DifferentialBaseGUID uniqueidentifier, BackupSetGUID uniqueidentifier, IsCopyOnly bit, DeleteCandidate bit not null default 0);

	begin try
		;with RawFiles as
		(
			select	distinct
					Path = e.full_filesystem_path,
					FileName = e.file_or_directory_name,
					ParentDir = iif(@IsLinux = 1, e.parent_directory, lower(replace(e.parent_directory, N'/', N'\') collate Latin1_General_100_CI_AS))
			from sys.dm_os_enumerate_filesystem(@Root, N'*') e
			where e.is_directory = 0
				and datalength(e.full_filesystem_path) <= 8000
				and datalength(e.parent_directory) <= 8000
				and (
					lower(right(e.file_or_directory_name, 4) collate Latin1_General_100_CI_AS) in (N'.bak', N'.trn')
					or lower(right(e.file_or_directory_name, 5) collate Latin1_General_100_CI_AS) = N'.diff'
				)
		), TrimmedParents as
		(
			select	Path, FileName,
					ParentDir = case
						when len(ParentDir) > 1 and right(ParentDir, 1) = @Separator then left(ParentDir, len(ParentDir) - 1)
						else ParentDir
					end
			from RawFiles
		)
		insert into #Files (Path, FileName, ContainerFolder)
			select	Path, FileName,
					case
						when p.Pos > 1 and len(ParentDir) > p.Pos and upper(right(ParentDir, p.Pos - 1) collate Latin1_General_100_CI_AS) in (N'FULL', N'DIFF', N'LOG')
							then left(ParentDir, len(ParentDir) - p.Pos)
						else ParentDir
					end
			from TrimmedParents
				cross apply (select charindex(@Separator, reverse(ParentDir)) Pos) p;
	end try
	begin catch
		return;
	end catch;

	if not exists (select 1 from #Files)
		return;

	if @UseBackupHeader = 0
	begin
		update f
			set GroupKey = f.ContainerFolder + N'|' + iif(@IsLinux = 1, p.DatabaseName collate Latin1_General_100_BIN2, lower(p.DatabaseName collate Latin1_General_100_CI_AS) collate Latin1_General_100_BIN2),
				BackupType = p.BackupType,
				BackupTime = p.BackupTime,
				IsCopyOnly = isnull(p.IsCopyOnly, 0)
		from #Files f
			cross apply z.fn_DecodeBackupFileName(f.FileName) p;

		update #Files
			set DeleteCandidate = 1
		where BackupType is not null
			and BackupTime < @Cutoff
			and (@TargetTypeCode is null or BackupType = @TargetTypeCode);

		if not exists (select 1 from #Files where DeleteCandidate = 1)
			return;

		if @KeepLatestChain = 1
		begin
			;with ActiveGroups as
			(
				select	distinct GroupKey
				from #Files
				where DeleteCandidate = 1
			), RankedAnyFulls as
			(
				select	f.GroupKey, f.Path, f.BackupTime,
						AnyRank = row_number() over (partition by f.GroupKey order by f.BackupTime desc, f.Path desc)
				from #Files f
					inner join ActiveGroups a on a.GroupKey = f.GroupKey
				where f.BackupType = 1
			), KeptAnyFulls as
			(
				select	GroupKey, Path, BackupTime
				from RankedAnyFulls
				where AnyRank = 1
			), RankedRealFulls as
			(
				select	f.GroupKey, f.Path, f.BackupTime,
						RealRank = row_number() over (partition by f.GroupKey order by f.BackupTime desc, f.Path desc)
				from #Files f
					inner join ActiveGroups a on a.GroupKey = f.GroupKey
				where f.BackupType = 1
					and isnull(f.IsCopyOnly, 0) = 0
			), KeptRealFulls as
			(
				select	GroupKey, Path, BackupTime
				from RankedRealFulls
				where RealRank = 1
			), RankedDiffs as
			(
				select	d.GroupKey, d.Path, d.BackupTime,
						DiffRank = row_number() over (partition by d.GroupKey order by d.BackupTime desc, d.Path desc)
				from #Files d
					inner join ActiveGroups a on a.GroupKey = d.GroupKey
					left join KeptRealFulls krf on krf.GroupKey = d.GroupKey
				where d.BackupType = 5
					and (krf.GroupKey is null or d.BackupTime >= krf.BackupTime)
			), KeptDiffs as
			(
				select	GroupKey, Path, BackupTime
				from RankedDiffs
				where DiffRank = 1
			), ChainAnchors as
			(
				select	a.GroupKey,
						FullPath = iif(kd.Path is not null, krf.Path, kaf.Path),
						DiffPath = kd.Path,
						AnchorTime = coalesce(kd.BackupTime, kaf.BackupTime)
				from ActiveGroups a
					left join KeptAnyFulls kaf on kaf.GroupKey = a.GroupKey
					left join KeptRealFulls krf on krf.GroupKey = a.GroupKey
					left join KeptDiffs kd on kd.GroupKey = a.GroupKey
				where kd.Path is not null or kaf.Path is not null
			), RankedPredecessorLogs as
			(
				select	f.GroupKey, f.Path,
						LogRank = row_number() over (partition by f.GroupKey order by f.BackupTime desc, f.Path desc)
				from #Files f
					inner join ChainAnchors ca on ca.GroupKey = f.GroupKey
				where f.BackupType = 2
					and f.BackupTime < ca.AnchorTime
			)
			update f
				set DeleteCandidate = 0
			from #Files f
				inner join ChainAnchors ca on ca.GroupKey = f.GroupKey
				left join RankedPredecessorLogs pl on pl.Path = f.Path and pl.LogRank = 1
			where f.DeleteCandidate = 1
				and (
					f.Path = ca.FullPath
					or f.Path = ca.DiffPath
					or pl.Path is not null
					or (f.BackupType = 2 and f.BackupTime >= ca.AnchorTime)
				);
		end
	end
	else
	begin
		declare cMedia cursor local fast_forward for
			select	Path
			from #Files
			order by Path;
		open cMedia;
		fetch next from cMedia into @Path;
		while @@fetch_status = 0
		begin
			select	@HeaderJson = null;
			begin try
				exec z.usp_ReadBackupHeader @BackupFile = @Path, @HeaderJson = @HeaderJson output, @ReturnResult = 0;
				if (select count(*) from z.fn_DecodeBackupHeader(@HeaderJson)) = 1
					update f
						set GroupKey = isnull(lower(h.ServerName collate Latin1_General_100_CI_AS), N'') collate Latin1_General_100_BIN2 + N'|' + h.DatabaseName collate Latin1_General_100_BIN2,
							DatabaseName = h.DatabaseName collate Latin1_General_100_BIN2,
							FamilyGUID = h.FamilyGUID,
							BackupType = h.BackupType,
							BackupTime = h.BackupFinishDate,
							FirstLSN = h.FirstLSN,
							LastLSN = h.LastLSN,
							CheckpointLSN = h.CheckpointLSN,
							DifferentialBaseGUID = h.DifferentialBaseGUID,
							BackupSetGUID = h.BackupSetGUID,
							IsCopyOnly = isnull(h.IsCopyOnly, 0)
					from #Files f
						cross join z.fn_DecodeBackupHeader(@HeaderJson) h
					where f.Path = @Path collate Latin1_General_100_BIN2
						and h.DatabaseName is not null
						and h.BackupType in (1, 2, 5)
						and isnull(h.IsDamaged, 1) = 0
						and isnull(h.IsSnapshot, 1) = 0
						and isnull(h.HasIncompleteMetaData, 1) = 0;
			end try
			begin catch
			end catch;
			fetch next from cMedia into @Path;
		end
		close cMedia;
		deallocate cMedia;

		update #Files
			set DeleteCandidate = 1
		where BackupType is not null
			and BackupTime < @Cutoff
			and (@TargetTypeCode is null or BackupType = @TargetTypeCode);

		if not exists (select 1 from #Files where DeleteCandidate = 1)
			return;

		if @KeepLatestChain = 1
		begin
			;with ActiveGroups as
			(
				select	distinct GroupKey
				from #Files
				where DeleteCandidate = 1
			), RankedAnyFulls as
			(
				select	f.GroupKey, f.Path, f.FamilyGUID, f.FirstLSN,
						AnyRank = row_number() over (partition by f.GroupKey order by f.BackupTime desc, f.LastLSN desc, f.Path desc)
				from #Files f
					inner join ActiveGroups a on a.GroupKey = f.GroupKey
				where f.BackupType = 1
			), KeptAnyFulls as
			(
				select	GroupKey, Path, FamilyGUID, FirstLSN
				from RankedAnyFulls
				where AnyRank = 1
			), RankedRealFulls as
			(
				select	f.GroupKey, f.Path, f.FamilyGUID, f.BackupSetGUID, f.FirstLSN,
						RealRank = row_number() over (partition by f.GroupKey order by f.BackupTime desc, f.LastLSN desc, f.Path desc)
				from #Files f
					inner join ActiveGroups a on a.GroupKey = f.GroupKey
				where f.BackupType = 1
					and isnull(f.IsCopyOnly, 0) = 0
			), KeptRealFulls as
			(
				select	GroupKey, Path, FamilyGUID, BackupSetGUID, FirstLSN
				from RankedRealFulls
				where RealRank = 1
			), RankedDiffs as
			(
				select	d.GroupKey, d.Path, d.FamilyGUID, d.LastLSN,
						DiffRank = row_number() over (partition by d.GroupKey order by d.LastLSN desc, d.BackupTime desc, d.Path desc)
				from #Files d
					inner join ActiveGroups a on a.GroupKey = d.GroupKey
					left join KeptRealFulls krf on krf.GroupKey = d.GroupKey
				where d.BackupType = 5
					and (
						krf.GroupKey is null
						or (krf.BackupSetGUID is not null and d.DifferentialBaseGUID = krf.BackupSetGUID)
					)
			), KeptDiffs as
			(
				select	GroupKey, Path, FamilyGUID, LastLSN
				from RankedDiffs
				where DiffRank = 1
			), ChainAnchors as
			(
				select	a.GroupKey,
						FullPath = iif(kd.Path is not null, krf.Path, kaf.Path),
						DiffPath = kd.Path,
						ChainFamilyGUID = iif(kd.Path is not null, coalesce(krf.FamilyGUID, kd.FamilyGUID), kaf.FamilyGUID),
						LogCutoffLSN = coalesce(kd.LastLSN, kaf.FirstLSN)
				from ActiveGroups a
					left join KeptAnyFulls kaf on kaf.GroupKey = a.GroupKey
					left join KeptRealFulls krf on krf.GroupKey = a.GroupKey
					left join KeptDiffs kd on kd.GroupKey = a.GroupKey
				where kd.Path is not null or kaf.Path is not null
			)
			update f
				set DeleteCandidate = 0
			from #Files f
				inner join ChainAnchors ca on ca.GroupKey = f.GroupKey
			where f.DeleteCandidate = 1
				and (
					f.Path = ca.FullPath
					or f.Path = ca.DiffPath
					or (
						f.BackupType = 2
						and (ca.ChainFamilyGUID is null or f.FamilyGUID = ca.ChainFamilyGUID)
						and f.LastLSN >= ca.LogCutoffLSN
					)
				);
		end
	end

	declare cDeletions cursor local fast_forward for
		select	Path
		from #Files
		where DeleteCandidate = 1
		order by BackupTime, Path;
	open cDeletions;
	fetch next from cDeletions into @Path;
	while @@fetch_status = 0
	begin
		begin try
			if exists (select 1 from sys.dm_os_file_exists(@Path) where file_exists = 1)
				exec master.sys.xp_delete_files @Path;
		end try
		begin catch
		end catch;
		fetch next from cDeletions into @Path;
	end
	close cDeletions;
	deallocate cDeletions;
end
go
