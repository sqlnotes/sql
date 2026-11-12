/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/020-Backup/modules/1070%20Procedures/z.usp_BackupDatabasesParallel.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/020-Backup/docs/reference/z.usp_BackupDatabasesParallel.md

Creates one task per selected database, runs bounded Agent workers and waits.
*/
create or alter procedure z.usp_BackupDatabasesParallel
(
	@Databases nvarchar(max) = N'AllDatabases',
	@BackupType nvarchar(50) = N'Full',
	@BackupFolder nvarchar(4000) = null,
	@BackupCompression bit = 1,
	@OtherBackupOptions nvarchar(max) = null,
	@ServerName sysname = null,
	@BackupFileNameFormat nvarchar(4000) = N'{ServerName}${InstanceName}${DatabaseName}_{yyyyMMdd}_{HHmmssfffffff}',
	@MaxConcurrentWorkers int = 3,
	@BatchID bigint = null output
)
as
begin
	set nocount, xact_abort on;
	if @@trancount <> 0 or @@options & 2 = 2
		throw 50000, 'Parallel backup requires no transaction and implicit transactions off.', 1;

	if @MaxConcurrentWorkers is null or @MaxConcurrentWorkers <= 0
		throw 50000, 'MaxConcurrentWorkers must be positive.', 1;

	select @BackupType = upper(trim(@BackupType));

	if @BackupType is null or @BackupType not in (N'FULL', N'DIFF', N'LOG')
		throw 50000, 'BackupType must be Full, Diff or Log.', 1;

	declare	@DatabaseName sysname, @DatabaseID int, @CreateDate datetime, @TaskID int,
			@Wrapper sysname,
			@BatchName nvarchar(128) = @@servername + N' - ' + @BackupType + N' - ' + convert(nvarchar(27), sysdatetime(), 121),
			@BackupArguments nvarchar(max), @DatabaseLiteral nvarchar(max), @IdentityPredicate nvarchar(max),
			@SQL nvarchar(max), @Body nvarchar(max), @CleanupSQL nvarchar(max),
			@BatchSemaphore nvarchar(200), @Slot int;

	declare @Targets table (TaskID int primary key, DatabaseID int, DatabaseName sysname, CreateDate datetime, Wrapper nvarchar(128));
	select @BatchID = null;

	insert @Targets (TaskID, DatabaseID, DatabaseName, CreateDate)
		select row_number() over (order by Size desc, d.name) , d.database_id, d.name, d.create_date
		from sys.databases d
			cross apply(
							select sum(convert(bigint, m.size)) Size
							from sys.master_files m
							where m.database_id = d.database_id
								and m.type_desc = 'ROWS'
						) m
		where d.state_desc not in ('RESTORING', 'RECOVERING', 'RECOVERY_PENDING', 'SUSPECT', 'EMERGENCY')
			and d.name <> N'tempdb'
			and m.Size is not null
			and (
						@Databases = N'AllDatabases'
					or @Databases = N'UserDatabases' and d.name not in (N'master', N'model', N'msdb')
					or @Databases = N'SystemDatabases' and d.name in (N'master', N'model', N'msdb')
					or exists (select 1 from string_split(@Databases, N',') s where trim(s.value) = d.name)
				)

	if not exists (select 1 from @Targets) return;

	-- These literals become fixed arguments in each run-specific procedure.
	select @BackupArguments = convert(nvarchar(max), N', @BackupType = N''') + replace(@BackupType, N'''', N'''''') + N''''
		+ N', @BackupFolder = ' + isnull(N'N''' + replace(convert(nvarchar(max), @BackupFolder), N'''', N'''''') + N'''', N'null')
		+ N', @BackupCompression = ' + isnull(convert(nvarchar(4), @BackupCompression), N'null')
		+ N', @OtherBackupOptions = ' + isnull(N'N''' + replace(@OtherBackupOptions, N'''', N'''''') + N'''', N'null')
		+ N', @ServerName = ' + isnull(N'N''' + replace(@ServerName, N'''', N'''''') + N'''', N'null')
		+ N', @BackupFileNameFormat = ' + isnull(N'N''' + replace(convert(nvarchar(max), @BackupFileNameFormat), N'''', N'''''') + N'''', N'null') + N';';

	begin try
		-- Publish only a complete task definition set.
		begin tran;
		exec z.usp_CreateTaskQueueBatch @BatchID = @BatchID output, @BatchName = @BatchName,
			@MaxConcurrentWorkers = @MaxConcurrentWorkers, @BatchType = N'Backup';

		declare Targets cursor local fast_forward for select TaskID, DatabaseID, DatabaseName, CreateDate from @Targets order by TaskID;
		open Targets;
		fetch next from Targets into @TaskID, @DatabaseID, @DatabaseName, @CreateDate;
		while @@fetch_status = 0
		begin
			select @Wrapper = N'##backup_' + convert(nvarchar(86), @DatabaseName) + N'_' + replace(convert(nvarchar(36), newid()), N'-', N'');

			select @DatabaseLiteral = N'N''' + replace(@DatabaseName, N'''', N'''''') + N'''';
			select @IdentityPredicate = convert(nvarchar(max), N'database_id = ') + convert(nvarchar(11), @DatabaseID)
				+ N' and name = ' + @DatabaseLiteral + N' and create_date = convert(datetime, N'''
				+ convert(nvarchar(23), @CreateDate, 121) + N''', 121) and state = 0';
			select @SQL = N'create procedure ' + quotename(@Wrapper) + N'
as
begin
	set nocount, xact_abort on;
	if not exists (select 1 from sys.databases where ' + @IdentityPredicate + N')
		throw 50000, ''The selected database is no longer the same online database.'', 1;
	exec ' + quotename(db_name()) + N'.z.usp_BackupDatabase @Databases = ' + @DatabaseLiteral + @BackupArguments + N'
end;';
			if object_id(N'tempdb..' + quotename(@Wrapper), N'P') is null
				exec sys.sp_executesql @SQL;
			update @Targets set Wrapper = @Wrapper where TaskID = @TaskID;

			select @Body = (select quotename(@Wrapper) command, json_query(N'[]') parameters for json path, without_array_wrapper);
			exec z.usp_AddTaskQueueTask @BatchID = @BatchID, @TaskID = @TaskID, @TaskName = @DatabaseName,
				@TaskBody = @Body, @SortOrder = 1, @CompletionCondition = 'Finished', @MaxRetries = 0;
			fetch next from Targets into @TaskID, @DatabaseID, @DatabaseName, @CreateDate;
		end;
		close Targets;
		deallocate Targets;
		commit;

		exec z.usp_ExecuteTaskQueueBatch @BatchID = @BatchID;
		begin tran;
		select @BatchSemaphore = N'z.TaskQueue.Batch:' + convert(nvarchar(20), @BatchID);
		exec @Slot = z.usp_AcquireSemaphore @SemaphoreName = @BatchSemaphore, @TotalCount = 1, @LockOwner = 'Transaction';
		if @Slot <= 0 throw 50000, 'Cannot acquire the batch cleanup gate.', 1;
		if exists (select 1 from z.TaskQueueBatch where BatchID = @BatchID and Status in ('Ready', 'Running'))
			throw 50000, 'The batch was restarted before temporary command cleanup.', 1;
		exec z.usp_ValidateTaskQueueBatch @BatchID = @BatchID, @RequireIdle = 1, @ValidateCommands = 0;
		select @CleanupSQL = N'drop procedure if exists ' + string_agg(convert(nvarchar(max), quotename(Wrapper)), N', ') + N';'
			from @Targets where Wrapper is not null;
		exec tempdb.sys.sp_executesql @CleanupSQL;
		commit;
	end try
	begin catch
		if @@trancount > 0 rollback;
		throw;
	end catch;
end;
