create or alter function z.fn_CleanseScheduleParameter
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
returns @ret table(ScheduleID uniqueidentifier primary key, Frequency varchar(20), Interval int, ByDay varchar(8000), IntradayFrequency varchar(20), IntradayInterval int, ByTime varchar(8000), StartDate date, EndDate date, Description varchar(8000))
as
begin
	/*
This function could be implemented as an inline table valued function. however, when written in that way, the following query results in an error
select b.*
	from msdb.dbo.sysschedules a
cross apply z.fn_FromSQLAgentSchedule(a.freq_type, a.freq_interval, a.freq_subday_type, a.freq_subday_interval, a.freq_relative_interval, a.freq_recurrence_factor, a.active_start_date, a.active_end_date, a.active_start_time, a.active_end_time ) b	

Msg 8632, Level 17, State 8, Line 100
Internal error: An expression services limit has been reached. Please look for potentially complex expressions in your query, and try to simplify them.

	*/
	;with x0 as
	(
		select 
				case 
					--when @Frequency is null then 'Daily'
					when @Frequency like '%specific%' or @Frequency like '%custom%'  or @Frequency like '%adhoc%' or @Frequency like '%one%'  or @Frequency like '%onc%' then 'Specific'
					when @Frequency in ('Daily', 'Days', 'Day', 'D', 'DD') then 'Daily'
					when @Frequency in ('Weekly', 'Weeks', 'Week', 'W', 'WK') then 'Weekly'
					when @Frequency in ('Monthly', 'Months', 'Month', 'M', 'Mon', 'MM') then 'Monthly'
					when replace(replace(@Frequency, 'Starts', 'Start'), ' ', '') in ('Start', 'AgentStart', 'SQLAgentStart', 'S') then 'Agent Starts'
					when @Frequency in ('Idle', 'I') then 'Idle'
				end Frequency,
				nullif(replace(@ByDay, ' ', ''), '') ByDay,
				case 
					when @IntradayFrequency in ('Hourly', 'hours', 'hour', 'h', 'hh') then 'Hourly'
					when @IntradayFrequency in ('Minutes', 'minute', 'min', 'm', 'mm') then 'Minute'
					when @IntradayFrequency in ('Seconds', 'Second', 'sec') then 'Second'
					when @IntradayFrequency like '%specific%' or @IntradayFrequency like '%custom%'  or @IntradayFrequency like '%adhoc%' or @IntradayFrequency like '%one%'  or @IntradayFrequency like '%onc%' then 'Specific'
				end IntradayFrequency,
				nullif(replace(@ByTime, ' ', ''), '') ByTime
				
	),
	x1 as
	(
		select	x0.Frequency, 
				case when x0.Frequency in ('Daily', 'Weekly', 'Monthly') then iif(isnull(@Interval, 0) < 1, 1, @Interval) end Interval,
				case 
					when x0.Frequency = 'Specific' then
						(
							select string_agg(convert(varchar(8000), d.t, 121), ',') within group(order by t)
							from (
									select distinct try_convert(datetime2(0), rtrim(ltrim(value)), 121) t
									from string_split(@ByDay, ',') d
								) d
							where d.t is not null
						)
					when x0.Frequency = 'Weekly' then
						(
							select string_agg(a.WeekDayName, ',') within group(order by a.WeekDayID)
							from (
									select distinct
											case 
												when a.Value like '%Mon%' or a.Value like '%1%' then 'Monday'
												when a.Value like '%Tue%' or a.Value like '%2%' then 'Tuesday'
												when a.Value like '%Wed%' or a.Value like '%3%' then 'Wednesday'
												when a.Value like '%Thur%' or a.Value like '%4%' then 'Thursday'
												when a.Value like '%Fri%' or a.Value like '%5%' then 'Friday'
												when a.Value like '%Sat%' or a.Value like '%6%' then 'Saturday'
												when a.Value like '%Sun%' or a.Value like '%7%' then 'Sunday'
											end WeekDayName,
											case 
												when a.Value like '%Mon%' or a.Value like '%1%' then 1
												when a.Value like '%Tue%' or a.Value like '%2%' then 2
												when a.Value like '%Wed%' or a.Value like '%3%' then 3
												when a.Value like '%Thur%' or a.Value like '%4%' then 4
												when a.Value like '%Fri%' or a.Value like '%5%' then 5
												when a.Value like '%Sat%' or a.Value like '%6%' then 6
												when a.Value like '%Sun%' or a.Value like '%7%' then 7
											end WeekDayID
									from (
											select ltrim(rtrim(value)) Value
											from string_split(ByDay, ',') a
										) a
									where a.value <> ''
								) a
							where a.WeekDayID is not null
						)
					when x0.Frequency = 'Monthly' then
						(
							select string_agg(a.MonthDayName, ',') within group(order by a.MonthDayID)
							from (
									select distinct
											case 
												when try_cast(a.Value as int) is not null then a.Value
												else
													case
														when a.Value like '%first%' or a.Value like '%1st%' then 'First'
														when a.Value like '%second%' or a.Value like '%2nd%' then 'Second'
														when a.Value like '%third%' or a.Value like '%3rd%' then 'third'
														when a.Value like '%Fourth%' or a.Value like '%4th%' then 'Fourth'
														when a.Value like '%Last%' then 'Last'
													end + ' ' +
													case 
														when a.Value like '%Mon%' then 'Monday'
														when a.Value like '%Tue%' then 'Tuesday'
														when a.Value like '%Wed%' then 'Wednesday'
														when a.Value like '%Thur%' then 'Thursday'
														when a.Value like '%Fri%' then 'Friday'
														when a.Value like '%Sat%' then 'Saturday'
														when a.Value like '%Sun%' then 'Sunday'
														when a.Value like '%WeekDay%' then 'Weekday'
														when a.Value like '%Weekend%' then 'Weekend'
														when a.Value in('LastDay', 'FirstDay', 'SecondDay', 'ThirdDay', 'FourthDay', '1stDay', '2ndDay', '3rdDay', '4thDay') then 'Day'
													end 
											end MonthDayName,
											case 
												when try_cast(a.Value as int) between 1 and 31 then cast(a.Value as int)
												else
													case
														when a.Value like '%first%' or a.Value like '%1st%' then 10000
														when a.Value like '%second%' or a.Value like '%2nd%' then 20000
														when a.Value like '%third%' or a.Value like '%3rd%' then 30000
														when a.Value like '%Fourth%' or a.Value like '%4th%' then 40000
														when a.Value like '%Last%' then 50000
													end + 
													case 
														when a.Value like '%Mon%' then 100
														when a.Value like '%Tue%' then 200
														when a.Value like '%Wed%' then 300
														when a.Value like '%Thur%' then 400
														when a.Value like '%Fri%' then 500
														when a.Value like '%Sat%' then 600
														when a.Value like '%Sun%' then 700
														when a.Value like '%WeekDay%' then 800
														when a.Value like '%Weekend%' then 900
														when a.Value in('LastDay', 'FirstDay', 'SecondDay', 'ThirdDay', 'FourthDay', '1stDay', '2ndDay', '3rdDay', '4thDay') then 1000
													end 
											end MonthDayID
									from (
											select ltrim(rtrim(value)) Value
											from string_split(ByDay, ',') a
										) a
									where a.value <> ''
								) a
							where a.MonthDayID is not null
						)
				end ByDay,
				case when x0.Frequency in ('Daily', 'Weekly', 'Monthly') then x0.IntradayFrequency end IntradayFrequency,
				case when x0.Frequency in ('Daily', 'Weekly', 'Monthly') then
					case 
						when x0.IntradayFrequency = 'Second' then iif(isnull(@IntradayInterval, 0) < 10, 10, @IntradayInterval)
						when x0.IntradayFrequency in('Hourly', 'Minute') then iif(isnull(@IntradayInterval, 0) < 1, 1, @IntradayInterval)
					end 
				end IntradayInterval,
				case when x0.Frequency in ('Daily', 'Weekly', 'Monthly') then
					case 
						when x0.IntradayFrequency in ('Hourly', 'Minute', 'Second') then
							(
								select string_agg(r, ',') within group (order by r)
								from (
										select distinct
												case when charindex('-', Bytime) = 0 and  try_cast(a.Value as time(0)) is not null then cast(cast(Value as time(0)) as varchar(8000)) + '-' + cast(dateadd(second, -1, cast(Value as time(0))) as varchar(8000))
													else (
																select cast(try_cast(left(v, i -1) as time(0)) as varchar(8000)) + '-' + cast(try_cast(right(v, l-i) as time(0)) as varchar(8000))
																from (
																		select a.Value v, charindex('-', a.Value) i, len(a.Value) l
																	) b
																where i > 0 and i < l
														)
												end r
										from (
													select ltrim(rtrim(value)) Value
													from string_split(ByTime, ',') a
											) a
										where a.Value <> ''
									) r
								where r.r is not null
							)
						when x0.IntradayFrequency in ('Specific') then
							(
									select string_agg(r, ',') within group (order by r)
									from (
											select cast(a.Value as varchar(8000)) r
											from (
														select distinct try_cast(ltrim(rtrim(value)) as time(0)) Value
														from string_split(ByTime, ',') a
												) a
											where a.Value is not null
										) r
									where r.r is not null
								)
					end 
				end ByTime,
				isnull(case when Frequency <> 'Specific' then @StartDate else try_convert(date, ByDay, 121) end, '1990-01-01') StartDate,
				isnull(case when Frequency <> 'Specific' then @EndDate end, '9999-12-31') EndDate
		from x0
	),
	x2 as
	(
		select x1.Frequency, x1.Interval, x1.ByDay, x1.IntradayFrequency, x1.IntradayInterval, x1.ByTime, x1.StartDate, x1.EndDate,
			case x1.Frequency
				when 'Specific' then 'at time ' + replace(x1.ByDay, ',', ', ')
				when 'Agent Start' then 'when Agent Starts'
				when 'Idle' then 'when computer is idle'
				when 'Daily' then 
					case 
						when x1.Interval = 1 then 'every day'
						else 'every ' + cast(x1.Interval as varchar(8000)) + ' days'
					end 
				when 'Weekly' then 
					case 
						when x1.Interval = 1 then 'every week'
						else 'every ' + cast(x1.Interval as varchar(8000)) + ' weeks'
					end + ' on ' + replace(x1.ByDay, ',', ', ')
				when 'Monthly' then 
					case 
						when x1.Interval = 1 then 'every month'
						else 'every ' + cast(x1.Interval as varchar(8000)) + ' months'
					end + ' on ' + replace(x1.ByDay, ',', ', ')
			end 
			+  
			case when x1.Frequency in ('Daily', 'Weekly', 'Monthly') then
					case x1.IntradayFrequency
						when 'Specific' then ' at ' + replace(x1.ByTime, ',', ', ')
						when 'Hourly' then  ' every ' + cast(x1.IntradayInterval as varchar(8000)) +  ' hour' + case when x1.IntradayInterval > 1 then 's' else '' end
						when 'Minute' then  ' every ' + cast(x1.IntradayInterval as varchar(8000)) +  ' minute' + case when x1.IntradayInterval > 1 then 's' else '' end
						when 'Second' then  ' every ' + cast(x1.IntradayInterval as varchar(8000)) +  ' second' + case when x1.IntradayInterval > 1 then 's' else '' end
					end
					+ 
					case when x1.IntradayFrequency in ('Hourly', 'Minute', 'Second') then
							' between ' + replace(replace(x1.ByTime, '-', ' and '), ',', ', ')
						else ''
					end
					+
					case 
						when StartDate <= '1990-01-01' and EndDate >= '9999-12-31' then ''
						when StartDate <= '1990-01-01' and EndDate < '9999-12-31' then ' until ' + convert(varchar(8000), EndDate, 121)
						when StartDate > '1990-01-01' and EndDate >= '9999-12-31' then ' from ' + convert(varchar(8000), StartDate, 121)
						when StartDate > '1990-01-01' and EndDate < '9999-12-31' then ' from ' + convert(varchar(8000), StartDate, 121) + ' to ' + convert(varchar(8000), EndDate, 121)
					end
					
				else ''
			end
			as Description
		from x1
	)
	insert into @ret
	select	cast(
				hashbytes('MD5', 
							cast(x2.Frequency as varchar(10)) + '-' + cast(isnull(x2.Interval, -1) as varchar(max)) + '-' + isnull(x2.ByDay, ' ') + '-' 
							+ isnull(x2.IntradayFrequency, ' ') +'-' + cast(isnull(x2.IntradayInterval, -1) as varchar(max)) + '-' + isnull(x2.ByTime, ' ') + '-'
							+ convert(varchar(max), isnull(x2.StartDate, '1990-01-01'), 121) + '-' + convert(varchar(max), isnull(x2.EndDate, '1990-01-01'), 121)
					) 
				as uniqueidentifier) ScheduleID,
			x2.Frequency, x2.Interval, x2.ByDay, x2.IntradayFrequency, x2.IntradayInterval, x2.ByTime, x2.StartDate, x2.EndDate, x2.Description
	from x2
	where x2.Description is not null
	return
end
go