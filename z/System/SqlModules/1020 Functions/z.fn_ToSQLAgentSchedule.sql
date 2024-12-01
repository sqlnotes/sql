create or alter function z.fn_ToSQLAgentSchedule
(
	@Frequency varchar(20) = 'Daily', --Monthly, Weekly, Daily, Agent Start, idle, Specific
	@Interval int = 1, 
	@ByDay varchar(8000) = null,--'[Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday] or First ... or Second ... or third ... or Fourth ... or Last ..., 1, 2, 3, 4'
	@IntradayFrequency varchar(20) = 'Second', -- hourly, minute, second, Specific
	@IntradayInterval int = 10,
	@ByTime varchar(8000) = '00:00',
	@StartDate date = null,
	@EndDate date = null
)
returns table
as
return 
(
	with x0 as
	(
		select z.ScheduleID, z.Frequency, z.Interval, bd.value ByDay, IntradayFrequency, IntradayInterval, bt.value ByTime, StartDate, EndDate
		from z.fn_CleanseScheduleParameter(@Frequency, @Interval, @ByDay, @IntradayFrequency, @IntradayInterval, @ByTime, @StartDate, @EndDate) z
			outer apply string_split(z.ByDay, ',') bd
			outer apply string_split(z.ByTime, ',') bt
	),
	x1 as
	(
		select x0.ScheduleID, x0.Frequency, x0.Interval, x0.ByDay, x0.IntradayFrequency, x0.IntradayInterval, x0.ByTime, x0.StartDate, x0.EndDate,
				case 
					when x0.Frequency = 'Specific' then 1
					when x0.Frequency = 'Daily' then 4
					when x0.Frequency = 'Weekly' then 8
					when x0.Frequency = 'Monthly' and try_cast(x0.ByDay as int) is not null then 16
					when x0.Frequency = 'Monthly' and try_cast(x0.ByDay as int) is null then 32
					when x0.Frequency = 'Agent Starts' then 64
					when x0.Frequency = 'Idle' then 128
				end freq_type,
				isnull(
						case 
							when x0.Frequency = 'Daily' then Interval
							when x0.Frequency = 'Weekly' then 
								case x0.ByDay
									when 'Sunday' then 1
									when 'Monday' then 2
									when 'Tuesday' then 4
									when 'Wednesday' then 8
									when 'Thursday' then 16
									when 'Friday' then 32
									when 'Saturday' then 64
								end
							when x0.Frequency = 'Monthly' and try_cast(x0.ByDay as int) is not null then cast(x0.ByDay as int)
							when x0.Frequency = 'Monthly' and try_cast(x0.ByDay as int) is null then
								case 
									when x0.ByDay like '%Sun%' then 1
									when x0.ByDay like '%Mon%' then 2
									when x0.ByDay like '%Tue%' then 3
									when x0.ByDay like '%Wed%' then 4
									when x0.ByDay like '%Thur%' then 5
									when x0.ByDay like '%Fri%' then 6
									when x0.ByDay like '%Sat%' then 7
									when x0.ByDay like '%WeekDay%' then 9
									when x0.ByDay like '%WeekEnd%' then 10
									when x0.ByDay like '%Day%' then 8
								end
							else 0
						end, 
					0) freq_interval,
				isnull(
						case x0.IntradayFrequency
							When 'Specific' then 1
							When 'Second' then 2
							When 'Minute' then 4
							When 'Hourly' then 8
						end, 
					0) freq_subday_type,
				isnull(x0.IntradayInterval, 0) freq_subday_interval,
				isnull(
						case when x0.Frequency = 'Monthly' and try_cast(x0.ByDay as int) is null then
							case 
									when x0.ByDay like '%First%' then 1
									when x0.ByDay like '%Second%' then 2
									when x0.ByDay like '%Third%' then 4
									when x0.ByDay like '%Fourth%' then 8
									when x0.ByDay like '%Last%' then 16
							end
						end, 
					0)freq_relative_interval,
				isnull(case when x0.Frequency in ('Weekly', 'Monthly') then x0.Interval end, 0) freq_recurrence_factor,
				
				isnull(cast(format(iif(x0.Frequency = 'Specific', try_convert(date, x0.ByDay ,121), x0.StartDate), 'yyyyMMdd') as int), 19900101) active_start_date,
				isnull(cast(format(x0.EndDate, 'yyyyMMdd') as int), 99991231) active_end_date,

				isnull(cast(format(iif(x0.Frequency = 'Specific', cast(try_convert(datetime, x0.ByDay ,121) as time(0)), t.StartTime), 'hhmmss') as int), 0) active_start_time,
				isnull(cast(format(iif(x0.IntradayFrequency = 'Specific', null, t.EndTime), 'hhmmss') as int), 235959) active_end_time
		from x0
			outer apply(
						select	case when i > 0 then try_cast(left(v, i -1) as time(0)) else try_cast(v as time(0)) end StartTime, 
								case when i > 0 then try_cast(right(v, l-i) as time(0)) end EndTime
						from (
								select x0.ByTime v, charindex('-', x0.ByTime) i, len(x0.ByTime) l
							) b
					) t
	),
	x2 as
	(
		--select distinct x1.freq_type, x1.freq_interval, x1.freq_subday_type, x1.freq_subday_interval, x1.freq_relative_interval, x1.freq_recurrence_factor, x1.active_start_date, x1.active_end_date, x1.active_start_time, x1.active_end_time from x1
		select	case when x1.freq_type = 8 then cast(x1.freq_type as varchar) else cast(x1.freq_type as varchar) + '-' + cast(x1.freq_interval as varchar) end agg,
				x1.freq_type, sum(x1.freq_interval) freq_interval, x1.freq_subday_type, x1.freq_subday_interval, x1.freq_relative_interval, x1.freq_recurrence_factor, x1.active_start_date, x1.active_end_date, x1.active_start_time, x1.active_end_time
		from x1
		group by case when x1.freq_type = 8 then cast(x1.freq_type as varchar) else cast(x1.freq_type as varchar) + '-' + cast(x1.freq_interval as varchar) end,
			x1.freq_type, x1.freq_subday_type, x1.freq_subday_interval, x1.freq_relative_interval, x1.freq_recurrence_factor, x1.active_start_date, x1.active_end_date, x1.active_start_time, x1.active_end_time
	)
	select	cast('Schema z: ' + cast(x2.freq_type as varchar(1000)) + '-' + cast(x2.freq_interval as varchar(1000)) + '-' + cast(x2.freq_subday_type as varchar(1000)) + '-' + cast(x2.freq_subday_interval as varchar(1000)) + '-' + cast(x2.freq_relative_interval as varchar(1000)) + '-' + cast(x2.freq_recurrence_factor as varchar(1000)) + '-' + cast(x2.active_start_date as varchar(1000)) + '-' + cast(x2.active_end_date as varchar(1000)) + '-' + cast(x2.active_start_time as varchar(1000)) + '-' + cast(x2.active_end_time as varchar(1000)) as varchar(128)) as Name,
			x2.freq_type, x2.freq_interval, x2.freq_subday_type, x2.freq_subday_interval, x2.freq_relative_interval, x2.freq_recurrence_factor, x2.active_start_date, x2.active_end_date, x2.active_start_time, x2.active_end_time
	from x2
)
