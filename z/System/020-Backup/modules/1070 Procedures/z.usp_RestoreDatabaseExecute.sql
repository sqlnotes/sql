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
	@TargetDatabaseName sysname
)
as
begin
	set nocount, xact_abort on;
	if @@trancount <> 0
	begin
		set xact_abort off;
		throw 50000, 'RestoreDatabase cannot run inside a user transaction.', 1;
	end
	if object_id('tempdb..#RestorePlan') is null or object_id('tempdb..#RestoreTargetState') is null or object_id('tempdb..#RestoreFileMap') is null
		throw 50000, 'RestoreDatabaseExecute requires the caller completed restore plans.', 1;
	if not exists(select * from #RestoreTargetState where DatabaseName = @TargetDatabaseName)
		throw 50000, 'The destination has no completed restore plan.', 1;
	declare @IsLinux bit = z.fn_IsLinux(), @InitialDatabaseID int, @InitialState tinyint, @InitialStandby bit, @InitialCreateDate datetime,
		@Family uniqueidentifier, @RecoveryType varchar(10), @StandbyFile nvarchar(4000),
		@CurrentOrdinal int, @StepType varchar(10), @Sql nvarchar(max), @AccessChanged bit = 0, @AccessCreateDate datetime;
	select @InitialDatabaseID = InitialDatabaseID, @InitialState = InitialState, @InitialStandby = InitialStandby,
		@InitialCreateDate = InitialCreateDate, @Family = FamilyGUID, @RecoveryType = RecoveryType, @StandbyFile = StandbyFile
	from #RestoreTargetState where DatabaseName = @TargetDatabaseName;
	select * into #Plan from #RestorePlan where DatabaseName = @TargetDatabaseName;
	select * into #FileMap from #RestoreFileMap where DatabaseName = @TargetDatabaseName;
	create table #RestoreExecutionState
	(
		StateID tinyint not null primary key check (StateID = 1),
		AccessChanged bit not null,
		AccessCreateDate datetime
	);
	insert #RestoreExecutionState (StateID, AccessChanged, AccessCreateDate) values (1, 0, @InitialCreateDate);
	-- Recheck the destination after metadata inspection; native RESTORE also checks the media and restore state.
	if isnull(db_id(@TargetDatabaseName), -1) <> isnull(@InitialDatabaseID, -1)
		or exists(select * from sys.databases where database_id = @InitialDatabaseID and (state <> @InitialState or is_in_standby <> @InitialStandby or create_date <> @InitialCreateDate))
		throw 50000, 'The destination changed while the restore plan was being built; run the procedure again.', 1;
	begin try
		declare cRestoreCommands cursor local fast_forward for select Ordinal, BackupType, Command from #Plan order by Ordinal;
		open cRestoreCommands;
		fetch next from cRestoreCommands into @CurrentOrdinal, @StepType, @Sql;
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
			fetch next from cRestoreCommands into @CurrentOrdinal, @StepType, @Sql;
		end
		close cRestoreCommands;
		deallocate cRestoreCommands;
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
