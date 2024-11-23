create or alter procedure z.usp_CreateServiceJob 
(
	@Name nvarchar(255), 
	@ProcedureName nvarchar(max), 
	@Description nvarchar(max), 
	@DeleteAfterRun int = 0, -- 0, job will never be removed. 3, job will be removed after first run
	@Interval int = 10, -- in second, if -1, no schedule
	@DailyAt int = null, --hhmmss
	@CheckRegistry bit = 0
)
as
begin
	set nocount, xact_abort on
	declare @IntervalLocal int = @Interval, @CategoryName nvarchar(50) = 'Z Schema Jobs'
	
	begin try
	if @DeleteAfterRun not in (0, 3)
	begin
		raiserror('only 0 and 3 can be accepted. 0, job will never be removed. 3, job will be removed after first run', 16, 1)
		return
	end

	if object_id('tempdb..#Steps') is not null
		drop table #Steps
	if object_id('tempdb..#Schedule') is not null
		drop table #Schedule
	if object_id('tempdb..#JobSchedule') is not null
		drop table #JobSchedule

	create table #Steps
	(
		step_id int,step_name nvarchar(128), subsystem nvarchar(40), command nvarchar(max), flags int, 
		cmdexec_success_code int, on_success_action tinyint, on_success_step_id int, on_fail_action tinyint, on_fail_step_id int, 
		server nvarchar(128), database_name nvarchar(128), database_user_name nvarchar(128), retry_attempts int, retry_interval int, 
		os_run_priority int, output_file_name nvarchar(200), last_run_outcome int, last_run_duration int, last_run_retries int, 
		last_run_date int, last_run_time int, proxy_id int
	) 
	create table #Schedule
	(
		schedule_id int, schedule_uid uniqueidentifier,schedule_name nvarchar(128), enabled int, freq_type int,
		freq_interval int, freq_subday_type int, freq_subday_interval int, freq_relative_interval int, freq_recurrence_factor int,
		active_start_date int, active_end_date int, active_start_time int, active_end_time int, date_created datetime,
		schedule_description nvarchar(4000), job_count int
	)
	
	create table #JobSchedule
	(
		schedule_id int,schedule_name nvarchar(128), enabled int, freq_type int,
		freq_interval int, freq_subday_type int, freq_subday_interval int, freq_relative_interval int, freq_recurrence_factor int,
		active_start_date int, active_end_date int, active_start_time int, active_end_time int, date_created datetime,
		schedule_description nvarchar(4000), next_run_date int, mext_run_time int, schedule_uid uniqueidentifier, job_count int
	)

	insert into #Schedule
		exec msdb..sp_help_schedule
	
	declare @schedule_uid uniqueidentifier, @schedule_id int, @job_name nvarchar(128), @command nvarchar(128), @job_id uniqueidentifier = null, @ScheduleName nvarchar(128), @ScheduleType int, @FirstStep nvarchar(max), @DatabaseName nvarchar(128) = db_name(), @StepName nvarchar(128)
	
	select	@job_name = z.fn_GetServiceJobName(@Name),
			@command = 'exec ' + @ProcedureName,
			@StepName = 'Execute procedure ' + @ProcedureName + ' on ' + quotename(@DatabaseName),
			@FirstStep = 'declare @DatabaseName nvarchar(128) = ' + quotename(@DatabaseName, '''')+ '
if not (
			databasepropertyex(@DatabaseName, ''IsInStandBy'') = 0 and databasepropertyex(@DatabaseName, ''Status'') = ''ONLINE''  
		and databasepropertyex(@DatabaseName, ''UserAccess'') = ''MULTI_USER'' and databasepropertyex(@DatabaseName, ''Updateability'') = ''READ_WRITE''
	)
begin
	raiserror(''Job should not be running on this node.'', 16, 1)
end
'
	

	if @Interval is not null
	begin
		if @Interval <= 100
		begin
			select @ScheduleName = 'z Jobs - Every '+ cast (@Interval as varchar(20)) +' seconds'
			select @ScheduleType = 2
		end
		if @Interval > 100
		begin
			select @Interval = @Interval / 60 + case when @Interval % 60 > 0 then 1 else 0 end
			select @ScheduleName = 'z Jobs - Every '+ cast (@Interval as varchar(20)) +' minutes'
			select @ScheduleType = 4
		end

		if @Interval > 100
		begin
			select @Interval = @Interval / 60 + case when @Interval % 60 > 0 then 1 else 0 end
			select @ScheduleName = 'z Jobs - Every '+ cast (@Interval as varchar(20)) +' hours'
			select @ScheduleType = 8
		end
		if @Interval > 100
		begin
			raiserror('Invalid Schedule', 16, 1)
			return
		end
	end
	if @DailyAt is not null
	begin
		select @ScheduleName = 'z Jobs - Daily at '+ stuff(stuff(right('000000'+cast(@DailyAt as varchar(6)), 6), 3,0,':'), 6, 0, ':')
	end

	if @ScheduleName is null
	begin
		raiserror('Unsupported schedule %d', 16, 1, @Interval)
		return
	end
	select @schedule_uid = schedule_uid, @schedule_id = schedule_id from #Schedule where schedule_name = @ScheduleName
	if @@rowcount = 0
	begin
		if @Interval is not null
		begin
			exec  msdb.dbo.sp_add_schedule	@schedule_uid = @schedule_uid output, @schedule_id = @schedule_id output, 
											@schedule_name=@ScheduleName, @enabled=1, 
											@freq_type=4, @freq_interval=1, @freq_subday_type=@ScheduleType, @freq_subday_interval=@Interval, 
											@freq_relative_interval=0, @freq_recurrence_factor=0, @active_start_date=20170720, 
											@active_end_date=99991231, @active_start_time=0, @active_end_time=235959
		end
		if @DailyAt is not null
		begin
			exec  msdb.dbo.sp_add_schedule	@schedule_uid = @schedule_uid output, @schedule_id = @schedule_id output, 
											@schedule_name=@ScheduleName, @enabled=1, 
											@freq_type=4, @freq_interval=1, @freq_subday_type=1, @freq_subday_interval=0, 
											@freq_relative_interval=0, @freq_recurrence_factor=0, @active_start_date=20170720, 
											@active_end_date=99991231, @active_start_time=@DailyAt, @active_end_time=235959
		end
	end
	
	select @job_id = (select job_id from msdb.dbo.sysjobs where name = @job_name)
	if @job_id is not null
	begin
		insert into #JobSchedule
			exec msdb..sp_help_jobschedule @job_name = @job_name
		insert into #Steps
			exec msdb..sp_help_jobstep @job_name = @job_name
	end
	begin transaction
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
	
	if @job_id is null
	begin
		exec msdb.dbo.sp_add_job @job_name= @job_name, @enabled=1, @notify_level_eventlog=0, @notify_level_email=0, @notify_level_netsend=0, @notify_level_page=0, @delete_level=@DeleteAfterRun, @description=@Description, /*@category_name=N'z Jobs',*/ @owner_login_name=null, @job_id = @job_id output
		exec msdb.dbo.sp_add_jobstep @job_id=@job_id, @step_name = 'Check Database Status', @step_id=1, @cmdexec_success_code=0, @on_success_action=3, @on_success_step_id=0, @on_fail_action=1, @on_fail_step_id=0, @retry_attempts=0, @retry_interval=0, @os_run_priority=0, @subsystem=N'TSQL', @command=@FirstStep, @database_name=N'master', @flags=0
		exec msdb.dbo.sp_add_jobstep @job_id=@job_id, @step_name = @StepName, @step_id=2, @cmdexec_success_code=0,  @on_success_action=1, @on_success_step_id=0, @on_fail_action=2, @on_fail_step_id=0, @retry_attempts=0, @retry_interval=0, @os_run_priority=0, @subsystem=N'TSQL', @command=@command, @database_name=@DatabaseName, @flags=0
		exec msdb.dbo.sp_attach_schedule @job_id=@job_id,@schedule_id = @schedule_id
		exec msdb.dbo.sp_update_job @job_id = @job_id, @start_step_id = 1
		exec msdb.dbo.sp_add_jobserver @job_id = @job_id, @server_name = N'(local)'
	end
	
	if is_srvrolemember('sysadmin') = 1
	begin
		exec msdb.dbo.sp_update_job @job_name=@job_name, @owner_login_name=N'sa'
	end
	exec msdb.dbo.sp_attach_schedule @job_id=@job_id,@schedule_id = @schedule_id
	if (
		(@Interval is not null or @DailyAt is not null) and exists(select * from #JobSchedule where schedule_id <> @schedule_id)
		or (
				not exists(select * from #Steps where step_name = 'Check Database Status' and command = @FirstStep) 
			or not exists(select * from #Steps where step_name = @StepName)
			) and exists(select* from #Steps)
		)
	begin
		exec msdb..sp_delete_job @job_id = @job_id
		exec z.usp_CreateServiceJob @Name = @Name, @ProcedureName = @ProcedureName, @Description = @Description, @DeleteAfterRun = @DeleteAfterRun, @Interval = @IntervalLocal, @DailyAt = @DailyAt
	end
	commit
	end try
	begin catch
		if @@trancount >0 
			rollback;
		throw;
	end catch
end
