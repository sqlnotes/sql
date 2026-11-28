/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/020-Backup/modules/1070%20Procedures/z.usp_CleanupBackupRestoreObjects.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/020-Backup/docs/reference/z.usp_CleanupBackupRestoreObjects.md

Removes leftover multi-threaded backup and restore procedures and idle worker jobs whose parent session is no longer active.
*/
create or alter procedure z.usp_CleanupBackupRestoreObjects
as
begin
	set nocount, xact_abort on;
	if @@trancount > 0 or @@options & 2 = 2
		throw 50000, 'Cleanup of backup/restore objects cannot run inside a transaction or implicit transactions.', 1;

	declare @Permission sysname = case when convert(int, serverproperty('ProductMajorVersion')) >= 16
		then N'VIEW SERVER PERFORMANCE STATE' else N'VIEW SERVER STATE' end;
	if isnull(has_perms_by_name(null, null, @Permission), 0) <> 1
		throw 50000, 'Cleanup of backup/restore objects requires server session visibility.', 1;

	declare	@Operation nvarchar(32), @RunIDHex nvarchar(32), @ExecutorPrefix nvarchar(64), @WorkerPrefix nvarchar(64),
			@JobPrefix nvarchar(280), @ContextPrefix varchar(64), @ExpectedContextInfo varbinary(128),
			@RunJobPrefix nvarchar(320), @RunWorkerPrefix nvarchar(100), @ExecutorName nvarchar(100),
			@JobID uniqueidentifier, @JobName sysname, @ServicePrefix nvarchar(261) = N'z_' + quotename(db_name(), '(') + N'_',
			@ServiceJobName nvarchar(255), @ProcedureName sysname, @ObjectID int,
			@SemaphoreName nvarchar(200), @SemaphoreSlot int, @DropSql nvarchar(max);

	declare @Operations table
	(
		Operation nvarchar(32) primary key,
		ExecutorPrefix nvarchar(64) not null,
		WorkerPrefix nvarchar(64) not null,
		JobPrefix nvarchar(280) not null,
		ContextPrefix varchar(64) not null
	);
	insert into @Operations (Operation, ExecutorPrefix, WorkerPrefix, JobPrefix, ContextPrefix)
		values
			(N'BackupDatabase', N'usp_BackupDatabaseExecutor_', N'usp_BackupDatabaseWorker_', @ServicePrefix + N'BackupDatabase_', 'z.BackupDatabase:'),
			(N'RestoreDatabase', N'usp_RestoreDatabaseExecutor_', N'usp_RestoreDatabaseWorker_', @ServicePrefix + N'RestoreDatabase_', 'z.RestoreDatabase:');

	declare @Runs table
	(
		Operation nvarchar(32) not null,
		RunIDHex nvarchar(32) not null,
		primary key (Operation, RunIDHex)
	);

	insert into @Runs (Operation, RunIDHex)
		select	distinct c.Operation, c.RunIDHex
		from (
			select	o.Operation,
					substring(p.name, len(o.ExecutorPrefix) + 1, 32) collate database_default RunIDHex
			from sys.procedures p
				inner join @Operations o on left(p.name, len(o.ExecutorPrefix)) = o.ExecutorPrefix collate database_default
			where p.schema_id = schema_id('z')
				and len(p.name) = len(o.ExecutorPrefix) + 32
			union all
			select	o.Operation,
					substring(p.name, len(o.WorkerPrefix) + 1, 32) collate database_default RunIDHex
			from sys.procedures p
				inner join @Operations o on left(p.name, len(o.WorkerPrefix)) = o.WorkerPrefix collate database_default
			where p.schema_id = schema_id('z')
				and len(p.name) > len(o.WorkerPrefix) + 33
				and substring(p.name, len(o.WorkerPrefix) + 33, 1) = N'_'
			union all
			select	o.Operation,
					substring(j.name collate database_default, len(o.JobPrefix) + 1, 32) RunIDHex
			from msdb.dbo.sysjobs j
				inner join @Operations o on left(j.name collate database_default, len(o.JobPrefix)) = o.JobPrefix
			where len(j.name collate database_default) > len(o.JobPrefix) + 33
				and substring(j.name collate database_default, len(o.JobPrefix) + 33, 1) = N'_'
		) c
		where len(c.RunIDHex) = 32
			and c.RunIDHex collate Latin1_General_100_BIN2 not like N'%[^0-9a-f]%';

	declare cRuns cursor local fast_forward for
		select	r.Operation, r.RunIDHex, o.ExecutorPrefix, o.WorkerPrefix, o.JobPrefix, o.ContextPrefix
		from @Runs r
			inner join @Operations o on o.Operation = r.Operation
		order by r.Operation, r.RunIDHex;
	open cRuns;
	fetch next from cRuns into @Operation, @RunIDHex, @ExecutorPrefix, @WorkerPrefix, @JobPrefix, @ContextPrefix;
	while @@fetch_status = 0
	begin
		select	@ExpectedContextInfo = convert(varbinary(128), @ContextPrefix + convert(varchar(32), @RunIDHex)),
				@RunJobPrefix = @JobPrefix + @RunIDHex + N'_',
				@RunWorkerPrefix = @WorkerPrefix + @RunIDHex + N'_',
				@ExecutorName = @ExecutorPrefix + @RunIDHex;

		if exists (
			select	1
			from sys.dm_exec_requests r
			where r.context_info = @ExpectedContextInfo
		)
		begin
			fetch next from cRuns into @Operation, @RunIDHex, @ExecutorPrefix, @WorkerPrefix, @JobPrefix, @ContextPrefix;
			continue;
		end;

		if exists (
			select	1
			from msdb.dbo.sysjobs j
			where left(j.name collate database_default, len(@RunJobPrefix)) = @RunJobPrefix
				and z.fn_IsSQLJobRunning(j.job_id) = 1
		)
		begin
			fetch next from cRuns into @Operation, @RunIDHex, @ExecutorPrefix, @WorkerPrefix, @JobPrefix, @ContextPrefix;
			continue;
		end;

		declare cJobs cursor local static read_only for
			select	j.job_id, j.name collate database_default
			from msdb.dbo.sysjobs j
			where left(j.name collate database_default, len(@RunJobPrefix)) = @RunJobPrefix
			order by j.name collate database_default;
		open cJobs;
		fetch next from cJobs into @JobID, @JobName;
		while @@fetch_status = 0
		begin
			begin try
				if z.fn_IsSQLJobRunning(@JobID) = 0
				begin
					select	@ServiceJobName = substring(@JobName, len(@ServicePrefix) + 1, 128);
					exec z.usp_RemoveServiceJob @Name = @ServiceJobName;
				end;
			end try
			begin catch
				if @@trancount > 0
					rollback;
			end catch;
			fetch next from cJobs into @JobID, @JobName;
		end;
		close cJobs;
		deallocate cJobs;

		if exists (
			select	1
			from msdb.dbo.sysjobs j
			where left(j.name collate database_default, len(@RunJobPrefix)) = @RunJobPrefix
				and z.fn_IsSQLJobRunning(j.job_id) = 1
		)
		begin
			fetch next from cRuns into @Operation, @RunIDHex, @ExecutorPrefix, @WorkerPrefix, @JobPrefix, @ContextPrefix;
			continue;
		end;

		declare cProcedures cursor local static read_only for
			select	p.name, p.object_id
			from sys.procedures p
			where p.schema_id = schema_id('z')
				and (
					left(p.name, len(@RunWorkerPrefix)) = @RunWorkerPrefix collate database_default
					or p.name = @ExecutorName collate database_default
				)
			order by iif(p.name = @ExecutorName collate database_default, 1, 0), p.name;
		open cProcedures;
		fetch next from cProcedures into @ProcedureName, @ObjectID;
		while @@fetch_status = 0
		begin
			select	@SemaphoreName = concat(N'z.ExecuteProcedures:', @ObjectID),
					@SemaphoreSlot = 0;
			begin try
				exec @SemaphoreSlot = z.usp_AcquireSemaphore @SemaphoreName = @SemaphoreName, @TotalCount = 1, @LockOwner = 'Session', @LockTimeout = 0;
				if @SemaphoreSlot > 0
				begin
					select	@DropSql = N'drop procedure if exists [z].' + quotename(@ProcedureName) + N';';
					exec(@DropSql);
				end;
			end try
			begin catch
				if @@trancount > 0
					rollback;
			end catch;
			if @SemaphoreSlot > 0
				exec z.usp_ReleaseSemaphore @SemaphoreName = @SemaphoreName, @SuppressException = 1, @Slot = @SemaphoreSlot, @LockOwner = 'Session';
			fetch next from cProcedures into @ProcedureName, @ObjectID;
		end;
		close cProcedures;
		deallocate cProcedures;

		fetch next from cRuns into @Operation, @RunIDHex, @ExecutorPrefix, @WorkerPrefix, @JobPrefix, @ContextPrefix;
	end;
	close cRuns;
	deallocate cRuns;
end;
go
