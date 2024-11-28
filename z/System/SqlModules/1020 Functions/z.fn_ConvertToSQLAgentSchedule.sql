create or alter function z.fn_ConvertToSQLAgentSchedule
(
	@Frequency varchar(20) = 'Daily', --Monthly, Weekly, Daily, Agent Start, idle, One time
	@Interval int = 1, 
	@ByDay varchar(1000) = null,--'[Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday] or First {...} or Second {...} or Thrid {...} or Forth {...} or Last {...}'
	@ByDate int = null,
	@SubDayFrequency varchar(20) = 'Second', -- hourly, minute, second, One time
	@SubDayInterval int = null,
	@SubDayStartTime time(0) = null,
	@SubDayEndTime time(0) = null,
	@ScheduleStartDate date = null,
	@ScheduleEndDate date = null
)
returns table
as
return 
(
	with x0 as
	(
		select case 
					when @Frequency in ('One time', 'Once', 'OneTime') then 1
					when @Frequency in ('Daily', 'Days') then 4
					when @Frequency in ('Weekly', 'Weeks') then 8
					when @Frequency in ('Monthly', 'Months') and @ByDate is not null then 16
					when @Frequency in ('Monthly', 'Months') and @ByDay is not null then 32
					when replace(replace(@Frequency, 'Starts', 'Start'), ' ', '') in ('Start', 'AgentStart', 'SQLAgentStart') then 64
					when @Frequency in ('Idle') then 128
				end
	)
	select 
			@Frequency freq_type,
			case 
				when @Frequency = 4 then @Interval
			end freq_interval,
			case 
				when @SubDayFrequency in ('Hourly', 'hours', 'hour') then 8
				when @SubDayFrequency in ('Minutes', 'minute') then 4
				when @SubDayFrequency in ('Seconds', 'Second') then 2
				when @SubDayFrequency in ('One time', 'Once', 'OneTime') then 1
			end freq_subday_type,
			@SubDayInterval	as freq_subday_interval,
			null as freq_relative_interval,
			null as freq_recurrence_factor,
			null as active_start_date,
			null active_end_date,
			null as active_start_time,
			null as active_end_time
	from x0
		
)