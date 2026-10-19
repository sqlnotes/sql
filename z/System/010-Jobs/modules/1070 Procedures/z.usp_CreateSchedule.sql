create or alter procedure z.usp_CreateSchedule
(
	@Frequency varchar(20) = 'Daily', --Monthly, Weekly, Daily, Agent Start, idle, Specific
	@Interval int = 1, 
	@ByDay varchar(8000) = null,--'[Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday] or First ... or Second ... or third ... or Fourth ... or Last ..., 1, 2, 3, 4'
	@IntradayFrequency varchar(20) = 'Second', -- hourly, minute, second, Specific
	@IntradayInterval int = 10,
	@ByTime varchar(8000) = '00:00',
	@StartDate date = null,
	@EndDate date = null,
	@ScheduleNames nvarchar(max) = null output
)
as
begin
	set nocount, xact_abort on
	declare @ValidationError nvarchar(4000) = z.fn_ValidateScheduleParameter(@Frequency, @Interval, @ByDay, @IntradayFrequency, @IntradayInterval, @ByTime, @StartDate, @EndDate);
	select @ScheduleNames = null;
	if @ValidationError is not null throw 51000, @ValidationError, 1;
	create table #DesiredSchedules
	(
		Name sysname, freq_type int, freq_interval int, freq_subday_type int, freq_subday_interval int, freq_relative_interval int,
		freq_recurrence_factor int, active_start_date int, active_end_date int, active_start_time int, active_end_time int
	)
	insert into #DesiredSchedules (Name, freq_type, freq_interval, freq_subday_type, freq_subday_interval, freq_relative_interval, freq_recurrence_factor, active_start_date, active_end_date, active_start_time, active_end_time)
		select Name, freq_type, freq_interval, freq_subday_type, freq_subday_interval, freq_relative_interval, freq_recurrence_factor, active_start_date, active_end_date, active_start_time, active_end_time
		from z.fn_ToSQLAgentSchedule(@Frequency, @Interval, @ByDay, @IntradayFrequency, @IntradayInterval, @ByTime, @StartDate, @EndDate)
	create table #ExistingSchedules(
							schedule_id int primary key, schedule_uid uniqueidentifier, schedule_name sysname, enabled int, 
							freq_type int, freq_interval int, freq_subday_type int, freq_subday_interval int, freq_relative_interval int,
							freq_recurrence_factor int, active_start_date int, active_end_date int, active_start_time int, active_end_time int,
							date_created datetime, schedule_description	nvarchar(4000), job_count int
							index schedule_name(schedule_name)
						)
	declare @Name sysname, @freq_type int, @freq_interval int, @freq_subday_type int, @freq_subday_interval int, @freq_relative_interval int, @freq_recurrence_factor int, @active_start_date int, @active_end_date int, @active_start_time int, @active_end_time int,
			@c cursor, @Resource nvarchar(255) = z.fn_ResourceSQLScheduleOperation(), @LockResult int, @DriftScheduleName sysname, @MismatchMessage nvarchar(2048)
	begin try
	set @c  = cursor local static for
		select Name, freq_type, freq_interval, freq_subday_type, freq_subday_interval, freq_relative_interval, freq_recurrence_factor, active_start_date, active_end_date, active_start_time, active_end_time
		from #DesiredSchedules
	open @c
	if @@cursor_rows =0
		throw 51000, 'The schedule definition did not produce any schedules; database-prefixed schedule names must fit the 128-character limit.', 1;
	begin tran
	exec @LockResult = sys.sp_getapplock @Resource = @Resource, @LockMode = N'Exclusive', @LockOwner = N'Transaction', @LockTimeout = 15000;
	if @LockResult < 0 throw 51001, 'Could not acquire the database schedule operation lock.', 1;
	insert into #ExistingSchedules(schedule_id, schedule_uid, schedule_name, enabled, freq_type, freq_interval, freq_subday_type, freq_subday_interval, freq_relative_interval, freq_recurrence_factor, active_start_date, active_end_date, active_start_time, active_end_time, date_created, schedule_description, job_count)
		exec msdb.dbo.sp_help_schedule -- do not directly access tables in MSDB, no access on AWS RDS.
	-- Check the whole requested set before creating any schedules. Enabled state is operator-owned.
	select top (1) @DriftScheduleName = d.Name
	from #DesiredSchedules d
		join #ExistingSchedules e on e.schedule_name = d.Name
	where exists
	(
		select e.freq_type, e.freq_interval, e.freq_subday_type, e.freq_subday_interval, e.freq_relative_interval,
			   e.freq_recurrence_factor, e.active_start_date, e.active_end_date, e.active_start_time, e.active_end_time
		except
		select d.freq_type, d.freq_interval, d.freq_subday_type, d.freq_subday_interval, d.freq_relative_interval,
			   d.freq_recurrence_factor, d.active_start_date, d.active_end_date, d.active_start_time,
			   case when d.active_end_time = 0 then 235959 else d.active_end_time end -- SQL Agent's stored end-of-day default.
	)
	order by d.Name, e.schedule_id
	if @DriftScheduleName is not null
	begin
		select @MismatchMessage = replace(N'Existing schedule "' + @DriftScheduleName + N'" has timing settings that differ from its generated name. Restore its timing settings or rename it before retrying.', N'%', N'%%');
		throw 51000, @MismatchMessage, 1;
	end
	fetch next from @c into @Name, @freq_type, @freq_interval, @freq_subday_type, @freq_subday_interval, @freq_relative_interval, @freq_recurrence_factor, @active_start_date, @active_end_date, @active_start_time, @active_end_time
	while @@fetch_status = 0
	begin
		if not exists(select * from #ExistingSchedules where schedule_name = @Name)
		begin
			exec msdb.dbo.sp_add_schedule @schedule_name = @name, @enabled = 1, @freq_type = @freq_type, @freq_interval = @freq_interval, @freq_subday_type = @freq_subday_type, @freq_subday_interval = @freq_subday_interval, @freq_relative_interval= @freq_relative_interval, @freq_recurrence_factor = @freq_recurrence_factor, @active_start_date = @active_start_date, @active_end_date = @active_end_date, @active_start_time = @active_start_time, @active_end_time = @active_end_time
		end
		select @ScheduleNames = case when @ScheduleNames is null then @Name else  @ScheduleNames + ',' + @Name end
		fetch next from @c into @Name, @freq_type, @freq_interval, @freq_subday_type, @freq_subday_interval, @freq_relative_interval, @freq_recurrence_factor, @active_start_date, @active_end_date, @active_start_time, @active_end_time
	end
	close @c
	deallocate @c
	commit
	end try
	begin catch
		select @ScheduleNames = null;
		if @@trancount > 0
			rollback;
		throw;
	end catch
end
go
