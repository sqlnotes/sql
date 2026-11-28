/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/020-Backup/modules/1070%20Procedures/z.usp_RestoreDatabaseExecute.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/020-Backup/docs/reference/z.usp_RestoreDatabase.md

Executes one validated target from the caller's completed restore plans.
*/
create or alter procedure z.usp_RestoreDatabaseExecute
(
	@TargetDatabaseName sysname,
	@BatchID uniqueidentifier = null,
	@SourceDatabaseName nvarchar(128) = null
)
as
begin
	set nocount, xact_abort on;
	if @@trancount <> 0
		throw 50000, 'RestoreDatabase cannot run inside a user transaction.', 1;
	if @@options & 2 = 2
		throw 50000, 'RestoreDatabase requires implicit transactions to be disabled.', 1;

	if object_id('tempdb..#RestorePlan') is null or object_id('tempdb..#RestoreTargetState') is null or object_id('tempdb..#RestoreFileMap') is null
		throw 50000, 'RestoreDatabaseExecute requires the caller completed restore plans.', 1;

	if not exists (select * from #RestoreTargetState where DatabaseName = @TargetDatabaseName)
		throw 50000, 'The destination has no completed restore plan.', 1;

	declare	@IsLinux bit = z.fn_IsLinux(), @InitialDatabaseID int, @InitialState tinyint, @InitialStandby bit, @InitialCreateDate datetime,
			@Family uniqueidentifier, @RecoveryType varchar(10), @StandbyFile nvarchar(4000),
			@CurrentOrdinal int, @StepType varchar(10), @Sql nvarchar(max), @AccessChanged bit = 0, @AccessCreateDate datetime,
			@RunBatchID uniqueidentifier = isnull(@BatchID, newid()), @StepStartTime datetime2(3) = sysutcdatetime(),
			@StepEndTime datetime2(3), @StepFile nvarchar(4000), @StepErrorNumber int, @StepErrorMessage nvarchar(512);

	select	@InitialDatabaseID = InitialDatabaseID, @InitialState = InitialState, @InitialStandby = InitialStandby,
			@InitialCreateDate = InitialCreateDate, @Family = FamilyGUID, @RecoveryType = RecoveryType, @StandbyFile = StandbyFile
	from #RestoreTargetState
	where DatabaseName = @TargetDatabaseName;

	select	* into #Plan from #RestorePlan where DatabaseName = @TargetDatabaseName;
	select	* into #FileMap from #RestoreFileMap where DatabaseName = @TargetDatabaseName;

	create table #RestoreExecutionState
	(
		StateID tinyint not null primary key check (StateID = 1),
		AccessChanged bit not null,
		AccessCreateDate datetime
	);
	insert #RestoreExecutionState (StateID, AccessChanged, AccessCreateDate)
		values (1, 0, @InitialCreateDate);

	-- Recheck destination identity before running the planned commands.
	if isnull(db_id(@TargetDatabaseName), -1) <> isnull(@InitialDatabaseID, -1)
		or exists (
			select	*
			from sys.databases
			where database_id = @InitialDatabaseID
				and (state <> @InitialState or is_in_standby <> @InitialStandby or create_date <> @InitialCreateDate)
		)
		throw 50000, 'The destination changed while the restore plan was being built; run the procedure again.', 1;

	begin try
		declare cRestoreCommands cursor local fast_forward for select Ordinal, BackupType, Command from #Plan order by Ordinal;
		open cRestoreCommands;
		fetch next from cRestoreCommands into @CurrentOrdinal, @StepType, @Sql;
		while @@fetch_status = 0
		begin
			select	@StepStartTime = sysutcdatetime(),
					@StepFile = null;
			select	@StepFile = isnull(BackupFile, iif(@StepType = 'FINALIZE' and @RecoveryType = 'STANDBY', @StandbyFile, null))
			from #Plan
			where Ordinal = @CurrentOrdinal;

			-- A preceding restore consumes the prior undo file; never overwrite an unrelated output file.
			if @RecoveryType = 'STANDBY' and @StepType = 'FINALIZE'
				and exists (select * from sys.dm_os_file_exists(@StandbyFile) where file_exists = 1 or file_is_a_directory = 1)
				throw 50000, 'The standby output path still exists after consuming prior undo; overwrite refused.', 1;

			exec z.usp_PrintString @Sql;
			exec(@Sql);

			if @StepType in ('FULL', 'DIFF', 'LOG', 'FINALIZE')
			begin
				select	@StepEndTime = sysutcdatetime();
				insert into z.BackupRestoreHistory (BatchID, Operation, DatabaseName, SourceDatabaseName, BackupType, RecoveryType, BackupFile, StartTime, EndTime, DurationMs, Status)
					values (@RunBatchID, 'Restore', @TargetDatabaseName, @SourceDatabaseName, @StepType, @RecoveryType, left(@StepFile, 1024), @StepStartTime, @StepEndTime, datediff_big(millisecond, @StepStartTime, @StepEndTime), 'Succeeded');
			end

			if @StepType = 'SINGLEUSER'
				select	@AccessChanged = 1, @AccessCreateDate = @InitialCreateDate;

			-- Refresh creation timestamp after an online restore only when planned family and mapped files match.
			if @StepType in ('FULL', 'DIFF', 'LOG', 'FINALIZE') and @AccessChanged = 1
				and not exists (
					select	*
					from #FileMap m
					where m.AddedOrdinal <= @CurrentOrdinal
						and not exists (
							select	*
							from sys.master_files f
							where f.database_id = @InitialDatabaseID
								and f.file_id = m.FileID
								and f.file_guid = m.UniqueID
								and m.NormalizedPath = iif(@IsLinux = 1, f.physical_name, lower(replace(f.physical_name, N'/', N'\'))) collate Latin1_General_100_BIN2
						)
				)
				and not exists (
					select	*
					from sys.master_files f
					where f.database_id = @InitialDatabaseID
						and not exists (select * from #FileMap m where m.FileID = f.file_id and m.AddedOrdinal <= @CurrentOrdinal)
				)
				select	@AccessCreateDate = d.create_date
				from sys.databases d
					inner join sys.database_recovery_status r on r.database_id = d.database_id
				where d.database_id = @InitialDatabaseID
					and d.name = @TargetDatabaseName
					and d.state = 0
					and r.family_guid = @Family;

			if @StepType = 'ACCESSMODE'
				select	@AccessChanged = AccessChanged from #RestoreExecutionState where StateID = 1;
			else
				update #RestoreExecutionState
					set AccessChanged = @AccessChanged, AccessCreateDate = @AccessCreateDate
				where StateID = 1;

			fetch next from cRestoreCommands into @CurrentOrdinal, @StepType, @Sql;
		end
		close cRestoreCommands;
		deallocate cRestoreCommands;
	end try
	begin catch
		if cursor_status('local', 'cRestoreCommands') >= 0 close cRestoreCommands;
		if cursor_status('local', 'cRestoreCommands') > -3 deallocate cRestoreCommands;
		select	@StepEndTime = sysutcdatetime(), @StepErrorNumber = error_number(), @StepErrorMessage = left(error_message(), 512);
		insert into z.BackupRestoreHistory (BatchID, Operation, DatabaseName, SourceDatabaseName, BackupType, RecoveryType, BackupFile, StartTime, EndTime, DurationMs, Status, ErrorNumber, ErrorMessage)
			values (@RunBatchID, 'Restore', @TargetDatabaseName, @SourceDatabaseName, @StepType, @RecoveryType, left(@StepFile, 1024), @StepStartTime, @StepEndTime, datediff_big(millisecond, @StepStartTime, @StepEndTime), 'Failed', @StepErrorNumber, @StepErrorMessage);

		select	@Sql = null;
		select	@Sql = Command from #Plan where BackupType = 'ACCESSMODE';
		if @AccessChanged = 1 and @Sql is not null
		begin
			exec z.usp_PrintString @Sql;
			begin try
				exec(@Sql);
			end try
			begin catch
				select	@Sql = N'Could not restore the destination access mode: ' + error_message();
				exec z.usp_PrintString @Sql;
			end catch
		end;
		throw;
	end catch
end
