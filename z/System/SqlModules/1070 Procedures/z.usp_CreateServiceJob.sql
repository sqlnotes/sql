create or alter procedure z.usp_CreateServiceJob 
(
	@Name nvarchar(255), 
	@Command nvarchar(max), 
	@Description nvarchar(max) = null, 
	@Frequency varchar(20) = 'Daily', --Monthly, Weekly, Daily, Agent Start, idle, Specific
	@Interval int = 1, 
	@ByDay varchar(8000) = null,--'[Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday] or First ... or Second ... or third ... or Fourth ... or Last ..., 1, 2, 3, 4'
	@IntradayFrequency varchar(20) = 'Second', -- hourly, minute, second, Specific
	@IntradayInterval int = 10,
	@ByTime varchar(8000) = '00:00',
	@StartDate date = null,
	@EndDate date = null,
	@DeleteAfterExecution bit = 0, -- 1, job will be removed after execution
	@CategoryName nvarchar(50) = 'Schema z Jobs'
)
as
begin
	set nocount, xact_abort on
	declare @IntervalLocal int = @Interval, @ScheduleNames varchar(max), @JobID uniqueidentifier, @JobName nvarchar(128), @StepName nvarchar(128), @FirstStep nvarchar(max), @DatabaseName nvarchar(128) = db_name(), 
			@AutomaticRemoveJobAfterExecution int =  case when isnull(@DeleteAfterExecution, 0) = 1 then 3 else 0 end, @ScheduleName nvarchar(128), @Operation char(1)
	if @Name is null or @Command is null
	begin
		raiserror('@Name and @Command must not be null.', 16, 1)
		return
	end
	create table #Steps
	(
		step_id int,step_name nvarchar(128), subsystem nvarchar(40), command nvarchar(max), flags int, 
		cmdexec_success_code int, on_success_action tinyint, on_success_step_id int, on_fail_action tinyint, on_fail_step_id int, 
		server nvarchar(128), database_name nvarchar(128), database_user_name nvarchar(128), retry_attempts int, retry_interval int, 
		os_run_priority int, output_file_name nvarchar(200), last_run_outcome int, last_run_duration int, last_run_retries int, 
		last_run_date int, last_run_time int, proxy_id int
	)
	create table #ScheduleNames(ScheduleName nvarchar(128) primary key)
	
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
			@FirstStep = 'declare @DatabaseName nvarchar(128) = ' + quotename(@DatabaseName, '''')+ '
if not (
			databasepropertyex(@DatabaseName, ''IsInStandBy'') = 0 and databasepropertyex(@DatabaseName, ''Status'') = ''ONLINE''  
		and databasepropertyex(@DatabaseName, ''UserAccess'') = ''MULTI_USER'' and databasepropertyex(@DatabaseName, ''Updateability'') = ''READ_WRITE''
	)
begin
	raiserror(''Job should not be running on this node.'', 16, 1)
end
'
	select @StepName = @JobName
	begin try
	begin tran
	exec z.usp_CreateSchedule @Frequency = @Frequency, @Interval = @Interval, @ByDay = @ByDay, @IntradayFrequency = @IntradayFrequency, @IntradayInterval = @IntradayInterval, @ByTime = @ByTime, @StartDate = @StartDate, @EndDate = @EndDate, @ScheduleNames = @ScheduleNames output
	insert into #ScheduleNames(ScheduleName)
		select value
		from string_split(@ScheduleNames, ',')

	
	select @JobID = (select job_id from msdb.dbo.sysjobs where name = @JobName)
	if @JobID is not null
	begin
		insert into #JobSchedule
			exec msdb..sp_help_jobschedule @job_name = @JobName
		insert into #Steps
			exec msdb..sp_help_jobstep @job_name = @JobName
		if exists(
					select * 
					from #Steps 
					where step_id = 1
						and command <> @FirstStep
				)
		begin
			exec msdb.dbo.sp_update_jobstep @job_id = @JobID, @step_id = 1, @command  = @FirstStep
		end
		if exists(
					select * 
					from #Steps 
					where step_id = 2
						and command <> @Command
				)
		begin
			exec msdb.dbo.sp_update_jobstep @job_id = @JobID, @step_id = 2, @command  = @Command
		end
		
	end
	else
	begin
		-- create a job without schedule defined
		exec msdb.dbo.sp_add_job @job_name= @JobName, @enabled = 1, @notify_level_eventlog = 0, @notify_level_email = 0, @notify_level_netsend = 0, @notify_level_page = 0, @delete_level = @AutomaticRemoveJobAfterExecution, @description = @Description, @category_name = @CategoryName, @owner_login_name = null, @job_id = @JobID output
		exec msdb.dbo.sp_add_jobstep @job_id = @JobID, @step_name = 'Check Database Status', @step_id = 1, @cmdexec_success_code = 0, @on_success_action = 3, @on_success_step_id = 0, @on_fail_action = 1, @on_fail_step_id = 0, @retry_attempts = 0, @retry_interval = 0, @os_run_priority = 0, @subsystem=N'TSQL', @command = @FirstStep, @database_name=N'master', @flags=0
		exec msdb.dbo.sp_add_jobstep @job_id = @JobID, @step_name = @StepName, @step_id = 2, @cmdexec_success_code = 0,  @on_success_action = 1, @on_success_step_id = 0, @on_fail_action = 2, @on_fail_step_id = 0, @retry_attempts = 0, @retry_interval = 0, @os_run_priority = 0, @subsystem = N'TSQL', @command = @Command, @database_name = @DatabaseName, @flags=0
		exec msdb.dbo.sp_add_jobserver @job_id = @JobID, @server_name = N'(local)'
		exec msdb.dbo.sp_update_job @job_id = @JobID, @start_step_id = 1		
	end
	-- put it here for now.
	if is_srvrolemember('sysadmin') = 1
	begin
		exec msdb.dbo.sp_update_job @job_id = @JobID, @owner_login_name=N'sa'
	end

	declare c cursor local for
		select	isnull(a.ScheduleName, b.schedule_name) ScheduleName,
				case
					when a.ScheduleName is null and b.schedule_name is not null then 'D'
					when a.ScheduleName is not null and b.schedule_name is null then 'I'
				end Operation
		from #ScheduleNames a
			full outer join #JobSchedule b on a.ScheduleName = b.schedule_name
		where isnull(a.ScheduleName, '') <> isnull(b.schedule_name, '')
	open c
	fetch next from c into @ScheduleName, @Operation
	while @@fetch_status = 0
	begin
		if @Operation = 'D'
		begin
			exec msdb.dbo.sp_detach_schedule @job_id = @JobID, @schedule_name = @ScheduleName
		end
		if @Operation = 'I'
		begin
			exec msdb.dbo.sp_attach_schedule @job_id = @JobID, @schedule_name = @ScheduleName
		end
		fetch next from c into @ScheduleName, @Operation
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
