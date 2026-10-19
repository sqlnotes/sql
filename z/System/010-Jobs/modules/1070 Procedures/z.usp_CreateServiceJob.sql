create or alter procedure z.usp_CreateServiceJob 
(
	@Name nvarchar(255), 
	@Command nvarchar(max) = null,
	@Description nvarchar(max) = null, 
	@Frequency varchar(20) = 'Daily', --Monthly, Weekly, Daily, Agent Start, idle, Specific
	@Interval int = 1, 
	@ByDay varchar(8000) = null,--'[Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday] or First ... or Second ... or third ... or Fourth ... or Last ..., 1, 2, 3, 4'
	@IntradayFrequency varchar(20) = 'Second', -- hourly, minute, second, Specific
	@IntradayInterval int = 10,
	@ByTime varchar(8000) = '00:00',
	@StartDate date = null,
	@EndDate date = null,
	@DeleteAfterExecution int = 0, -- 0: never, 1: on success, 2: on failure, 3: on completion
	@CategoryName nvarchar(50) = 'Schema z Jobs',
	@SetJobOwnerToSA bit = 1,
	@Command2 nvarchar(max) = null,
	@Command3 nvarchar(max) = null,
	@Command4 nvarchar(max) = null,
	@Command5 nvarchar(max) = null,
	@Command6 nvarchar(max) = null,
	@Command7 nvarchar(max) = null,
	@Command8 nvarchar(max) = null,
	@Command9 nvarchar(max) = null,
	@Command10 nvarchar(max) = null
)
as
begin
	set nocount, xact_abort on
	declare @Today date = convert(date, getdate());
	select @StartDate = isnull(@StartDate, @Today);
	declare @IntervalLocal int = @Interval, @ScheduleNames nvarchar(max), @ScheduleIDs nvarchar(max), @JobID uniqueidentifier, @JobName nvarchar(128), @StepName nvarchar(128), @FirstStep nvarchar(max), @DatabaseName nvarchar(128) = db_name(),
			@StepID int, @StepCommand nvarchar(max), @StepDatabase nvarchar(128), @OnSuccessAction tinyint, @OnFailAction tinyint, @ScheduleID int, @Operation char(1), @SAName nvarchar(128), @Resource nvarchar(255) = z.fn_ResourceSQLScheduleOperation(), @LockResult int, @RebuildSteps bit = 0, @IsNewJob bit = 0
	if @Name is null
		throw 50000, '@Name must not be null.', 1;
	declare @Commands table(ParameterOrdinal int primary key, Command nvarchar(max))
	insert into @Commands(ParameterOrdinal, Command)
		select c.ParameterOrdinal, c.Command
		from (values (1, @Command), (2, @Command2), (3, @Command3), (4, @Command4), (5, @Command5),
			(6, @Command6), (7, @Command7), (8, @Command8), (9, @Command9), (10, @Command10)) c(ParameterOrdinal, Command)
		where len(translate(c.Command collate Latin1_General_100_BIN2,
			nchar(9) + nchar(10) + nchar(11) + nchar(12) + nchar(13), N'     ')) > 0;
	if @DeleteAfterExecution is null or @DeleteAfterExecution not between 0 and 3
		throw 51000, '@DeleteAfterExecution must be 0 (never), 1 (on success), 2 (on failure), or 3 (on completion).', 1;
	declare @ValidationError nvarchar(4000) = z.fn_ValidateScheduleParameter(@Frequency, @Interval, @ByDay, @IntradayFrequency, @IntradayInterval, @ByTime, @StartDate, @EndDate);
	if @ValidationError is not null throw 51000, @ValidationError, 1;
	if not exists(select * from z.fn_ToSQLAgentSchedule(@Frequency, @Interval, @ByDay, @IntradayFrequency, @IntradayInterval, @ByTime, @StartDate, @EndDate))
		throw 51000, 'The schedule definition did not produce any schedules; database-prefixed schedule names must fit the 128-character limit.', 1;
	create table #Steps
	(
		step_id int,step_name nvarchar(128) collate database_default, subsystem nvarchar(40), command nvarchar(max), flags int,
		cmdexec_success_code int, on_success_action tinyint, on_success_step_id int, on_fail_action tinyint, on_fail_step_id int, 
		server nvarchar(128), database_name nvarchar(128), database_user_name nvarchar(128), retry_attempts int, retry_interval int, 
		os_run_priority int, output_file_name nvarchar(200), last_run_outcome int, last_run_duration int, last_run_retries int, 
		last_run_date int, last_run_time int, proxy_id int
	)
	create table #ScheduleIDs(ScheduleID int primary key)
	
	create table #JobSchedule
	(
		schedule_id int,schedule_name nvarchar(128), enabled int, freq_type int,
		freq_interval int, freq_subday_type int, freq_subday_interval int, freq_relative_interval int, freq_recurrence_factor int,
		active_start_date int, active_end_date int, active_start_time int, active_end_time int, date_created datetime,
		schedule_description nvarchar(4000), next_run_date int, mext_run_time int, schedule_uid uniqueidentifier, job_count int,
		index [idx_#JobSchedule_schedule_name] (schedule_name)
	)

	begin try
	if not exists(select * from msdb.dbo.syscategories where name = @CategoryName AND category_class = 1)
	begin
		-- AWS RDS does not support this procedure
		exec msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name = @CategoryName
	end
	end try
	begin catch
		select @CategoryName = null
	end catch

	select	@JobName = z.fn_GetServiceJobName(@Name),
			@FirstStep = 'declare @DatabaseName nvarchar(128) = N' + quotename(@DatabaseName, '''')+ ';
if isnull(databasepropertyex(@DatabaseName, ''IsInStandBy''), 1) <> 0
	or isnull(databasepropertyex(@DatabaseName, ''Status''), '''') <> ''ONLINE''
	or isnull(databasepropertyex(@DatabaseName, ''UserAccess''), '''') <> ''MULTI_USER''
	or isnull(databasepropertyex(@DatabaseName, ''Updateability''), '''') <> ''READ_WRITE''
begin
	throw 50000, ''Job should not be running on this node.'', 1;
end
'
	declare @DesiredSteps table
	(
		StepID int primary key,
		ParameterOrdinal int,
		StepName nvarchar(128),
		Command nvarchar(max),
		DatabaseName nvarchar(128),
		OnSuccessAction tinyint,
		OnFailAction tinyint
	)
	declare @ManagedStepNames table(ParameterOrdinal int primary key, StepName nvarchar(128))
	insert into @ManagedStepNames(ParameterOrdinal, StepName)
		values (0, N'Check Database Status'), (1, @JobName)
	insert into @ManagedStepNames(ParameterOrdinal, StepName)
		select ParameterOrdinal, N'Command ' + convert(nvarchar(2), ParameterOrdinal)
		from (values (2), (3), (4), (5), (6), (7), (8), (9), (10)) c(ParameterOrdinal)
	insert into @DesiredSteps(StepID, ParameterOrdinal, StepName, Command, DatabaseName, OnSuccessAction, OnFailAction)
		select 1, 0, N'Check Database Status', @FirstStep, N'master', case when exists(select 1 from @Commands) then 3 else 1 end, 1
	insert into @DesiredSteps(StepID, ParameterOrdinal, StepName, Command, DatabaseName, OnSuccessAction, OnFailAction)
		select 1 + row_number() over(order by c.ParameterOrdinal), c.ParameterOrdinal, n.StepName,
			c.Command, @DatabaseName,
			case when c.ParameterOrdinal = max(c.ParameterOrdinal) over() then 1 else 3 end, 2
		from @Commands c
			join @ManagedStepNames n on n.ParameterOrdinal = c.ParameterOrdinal
	begin try
	begin tran
	exec @LockResult = sys.sp_getapplock @Resource = @Resource, @LockMode = N'Exclusive', @LockOwner = N'Transaction', @LockTimeout = 15000;
	if @LockResult < 0 throw 51001, 'Could not acquire the database schedule operation lock.', 1;
	exec z.usp_CreateSchedule @Frequency = @Frequency, @Interval = @Interval, @ByDay = @ByDay, @IntradayFrequency = @IntradayFrequency, @IntradayInterval = @IntradayInterval, @ByTime = @ByTime, @StartDate = @StartDate, @EndDate = @EndDate, @ScheduleNames = @ScheduleNames output, @ScheduleIDs = @ScheduleIDs output, @OperationDate = @Today
	if nullif(@ScheduleNames, '') is null throw 51000, 'The schedule definition did not produce any schedules; database-prefixed schedule names must fit the 128-character limit.', 1;
	insert into #ScheduleIDs(ScheduleID)
		select convert(int, value) from openjson(@ScheduleIDs);

	select @JobID = (select job_id from msdb.dbo.sysjobs where name = @JobName)
	if @JobID is not null
	begin
		insert into #JobSchedule
			exec msdb..sp_help_jobschedule @job_name = @JobName
		insert into #Steps
			exec msdb..sp_help_jobstep @job_name = @JobName
		if exists(select * from #Steps s where s.step_id not between 1 and 11
			or (s.step_id not in (1, 2) and not exists(select * from @ManagedStepNames n where n.StepName = s.step_name)))
			throw 51000, 'The existing job has additional steps; remove them explicitly before reapplying its definition.', 1;
		if exists(select StepID from @DesiredSteps except select step_id from #Steps)
			or exists(select step_id from #Steps except select StepID from @DesiredSteps)
		begin
			-- Rebuild in order: native insertion/deletion can renumber surviving steps.
			exec msdb.dbo.sp_delete_jobstep @job_id = @JobID, @step_id = 0
			select @RebuildSteps = 1
		end
		else
		begin
			-- Free all changed names before restoring them, including arbitrary managed-name cycles.
			declare @TemporaryStepName nvarchar(128)
			declare RenameSteps cursor local fast_forward for
				select s.step_id from #Steps s join @DesiredSteps d on d.StepID = s.step_id
				where s.step_name <> d.StepName order by s.step_id
			open RenameSteps
			fetch next from RenameSteps into @StepID
			while @@fetch_status = 0
			begin
				select @TemporaryStepName = N'Schema z repair ' + convert(nvarchar(36), newid())
				exec msdb.dbo.sp_update_jobstep @job_id = @JobID, @step_id = @StepID, @step_name = @TemporaryStepName
				fetch next from RenameSteps into @StepID
			end
			close RenameSteps
			deallocate RenameSteps
		end
	end
	else
	begin
		-- create a job without schedule defined
		exec msdb.dbo.sp_add_job @job_name= @JobName, @enabled = 1, @notify_level_eventlog = 0, @notify_level_email = 0, @notify_level_netsend = 0, @notify_level_page = 0, @delete_level = @DeleteAfterExecution, @description = @Description, @category_name = @CategoryName, @owner_login_name = null, @job_id = @JobID output
		select @RebuildSteps = 1, @IsNewJob = 1
	end
	declare ManagedSteps cursor local fast_forward for
		select StepID, StepName, Command, DatabaseName, OnSuccessAction, OnFailAction from @DesiredSteps order by StepID
	open ManagedSteps
	fetch next from ManagedSteps into @StepID, @StepName, @StepCommand, @StepDatabase, @OnSuccessAction, @OnFailAction
	while @@fetch_status = 0
	begin
		if @RebuildSteps = 1
			exec msdb.dbo.sp_add_jobstep @job_id = @JobID, @step_name = @StepName, @step_id = @StepID, @cmdexec_success_code = 0,
				@on_success_action = @OnSuccessAction, @on_success_step_id = 0, @on_fail_action = @OnFailAction, @on_fail_step_id = 0,
				@retry_attempts = 0, @retry_interval = 0, @os_run_priority = 0, @subsystem = N'TSQL', @command = @StepCommand, @database_name = @StepDatabase, @flags = 0
		else
		begin
			exec msdb.dbo.sp_update_jobstep @job_id = @JobID, @step_id = @StepID, @step_name = @StepName, @cmdexec_success_code = 0,
				@on_success_action = @OnSuccessAction, @on_success_step_id = 0, @on_fail_action = @OnFailAction, @on_fail_step_id = 0,
				@retry_attempts = 0, @retry_interval = 0, @os_run_priority = 0, @subsystem = N'TSQL', @database_name = @StepDatabase, @flags = 0
			if exists(select * from #Steps where step_id = @StepID and command <> @StepCommand)
				exec msdb.dbo.sp_update_jobstep @job_id = @JobID, @step_id = @StepID, @command = @StepCommand
		end
		fetch next from ManagedSteps into @StepID, @StepName, @StepCommand, @StepDatabase, @OnSuccessAction, @OnFailAction
	end
	close ManagedSteps
	deallocate ManagedSteps
	if @IsNewJob = 1 exec msdb.dbo.sp_add_jobserver @job_id = @JobID, @server_name = N'(local)'
	exec msdb.dbo.sp_update_job @job_id = @JobID, @start_step_id = 1, @description = @Description, @category_name = @CategoryName, @delete_level = @DeleteAfterExecution
	-- put it here for now.
	if is_srvrolemember('sysadmin') = 1 and @SetJobOwnerToSA = 1
	begin
		select @SAName = name
		from sys.server_principals
		where sid = 0x01
		if @@rowcount > 0
		begin
			exec msdb.dbo.sp_update_job @job_id = @JobID, @owner_login_name = @SAName
		end
	end

	declare c cursor local for
		select isnull(a.ScheduleID, b.schedule_id) ScheduleID,
			case when a.ScheduleID is null then 'D' when b.schedule_id is null then 'I' end Operation
		from #ScheduleIDs a
			full outer join #JobSchedule b on a.ScheduleID = b.schedule_id
		where a.ScheduleID is null or b.schedule_id is null
		order by Operation desc -- Attach the replacement schedules before detaching the previous ones.
	open c
	fetch next from c into @ScheduleID, @Operation
	while @@fetch_status = 0
	begin
		if @Operation = 'D'
		begin
			exec msdb.dbo.sp_detach_schedule @job_id = @JobID, @schedule_id = @ScheduleID, @delete_unused_schedule = 0
		end
		if @Operation = 'I'
		begin
			exec msdb.dbo.sp_attach_schedule @job_id = @JobID, @schedule_id = @ScheduleID
		end
		fetch next from c into @ScheduleID, @Operation
	end
	close c
	deallocate c
	commit
	end try
	begin catch
		if @@trancount >0 
			rollback;
		throw;
	end catch
end
