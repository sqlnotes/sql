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
	@ScheduleNames varchar(max) = null output
)
as
begin
	set nocount, xact_abort on
	create table #ExistingSchedules(
							schedule_id int primary key, schedule_uid uniqueidentifier, schedule_name sysname, enabled int, 
							freq_type int, freq_interval int, freq_subday_type int, freq_subday_interval int, freq_relative_interval int,
							freq_recurrence_factor int, active_start_date int, active_end_date int, active_start_time int, active_end_time int,
							date_created datetime, schedule_description	nvarchar(4000), job_count int
							index schedule_name(schedule_name)
						)
	declare @Name sysname, @freq_type int, @freq_interval int, @freq_subday_type int, @freq_subday_interval int, @freq_relative_interval int, @freq_recurrence_factor int, @active_start_date int, @active_end_date int, @active_start_time int, @active_end_time int,
			@c cursor, @res nvarchar(100) = z.fn_ResourceSQLScheduleOperation()
	select @ScheduleNames = null
	begin try
	set @c  = cursor local static for
		select Name, freq_type, freq_interval, freq_subday_type, freq_subday_interval, freq_relative_interval, freq_recurrence_factor, active_start_date, active_end_date, active_start_time, active_end_time
		from z.fn_ToSQLAgentSchedule(@Frequency, @Interval, @ByDay, @IntradayFrequency, @IntradayInterval, @ByTime, @StartDate, @EndDate)
	open @c
	if @@cursor_rows =0
		return
	begin tran
	exec z.usp_AcquireSemaphore @res
	insert into #ExistingSchedules(schedule_id, schedule_uid, schedule_name, enabled, freq_type, freq_interval, freq_subday_type, freq_subday_interval, freq_relative_interval, freq_recurrence_factor, active_start_date, active_end_date, active_start_time, active_end_time, date_created, schedule_description, job_count)
		exec msdb.dbo.sp_help_schedule -- do not directly access tables in MSDB, no access on AWS RDS.
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
	exec z.usp_ReleaseSemaphore @res
	commit
	end try
	begin catch
		if @@trancount > 0
			rollback;
		throw;
	end catch
end
go
