create or alter function z.fn_StandardizeSchedule
(
	@Frequency varchar(20) = 'Daily', --Monthly, Weekly, Daily, Agent Start, idle, One time
	@Interval int = 1, 
	@ByDay varchar(1000) = null,--'[Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday] or First {...} or Second {...} or Thrid {...} or Forth {...} or Last {...}, 1, 2, 3, 4'
	@SubDayFrequency varchar(20) = 'Second', -- hourly, minute, second, One time
	@SubDayInterval int = null,
	@StartDate date = null,
	@StartTime time(0) = null,
	@EndTime time(0) = null,
	@EndDate date = null
)
returns table
as
return 
(
	with x0 as
	(
		select 
				case 
					when @Frequency is null then 'Daily'
					when @Frequency in ('One time', 'Once', 'OneTime') then 'Once'
					when @Frequency in ('Daily', 'Days') then 'Daily'
					when @Frequency in ('Weekly', 'Weeks') then 'Weekly'
					when @Frequency in ('Monthly', 'Months') then 'Monthly'
					when replace(replace(@Frequency, 'Starts', 'Start'), ' ', '') in ('Start', 'AgentStart', 'SQLAgentStart') then 'Agent Starts'
					when @Frequency in ('Idle') then 'Idle'
				end Frequency,
				case 
					when @SubDayFrequency in ('Hourly', 'hours', 'hour') then 'Hourly'
					when @SubDayFrequency in ('Minutes', 'minute') then 'Minute'
					when @SubDayFrequency in ('Seconds', 'Second') then 'Second'
					when @SubDayFrequency in ('One time', 'Once', 'OneTime') then 'Once'
				end SubDayFrequency,
				replace(@ByDay, ' ', '') ByDay,
				try_cast(@ByDay as int) ByDate
	),
	x1 as
	(
		select	x0.Frequency Frequency,
				isnull(@Interval, 1) Interval,
				case 
					when Frequency = 'Weekly' then
						(
							select string_agg(a.WeekDayName, ',') within group(order by a.WeekDayID)
							from (
									select 
											case 
												when a.Value like '%Mon%' or a.Value like '%1%' then 'Monday'
												when a.Value like '%Tue%' or a.Value like '%2%' then 'Tuesday'
												when a.Value like '%Wed%' or a.Value like '%3%' then 'Wednesday'
												when a.Value like '%Thur%' or a.Value like '%4%' then 'Thursday'
												when a.Value like '%Fri%' or a.Value like '%5%' then 'Friday'
												when a.Value like '%Saturday%' or a.Value like '%6%' then 'Saturday'
												when a.Value like '%Sun%' or a.Value like '%7%' then 'Sunday'
											end WeekDayName,
											case 
												when a.Value like '%Mon%' or a.Value like '%1%' then 1
												when a.Value like '%Tue%' or a.Value like '%2%' then 2
												when a.Value like '%Wed%' or a.Value like '%3%' then 3
												when a.Value like '%Thur%' or a.Value like '%4%' then 4
												when a.Value like '%Fri%' or a.Value like '%5%' then 5
												when a.Value like '%Saturday%' or a.Value like '%6%' then 6
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
					when Frequency = 'Monthly' then
						case
							when ByDay like '%first%' or ByDay like '%1%' then 'First'
							when ByDay like '%second%' or ByDay like '%2%' then 'Second'
							when ByDay like '%Thrid%' or ByDay like '%3%' then 'Thrid'
							when ByDay like '%Forth%' or ByDay like '%4%' then 'Forth'
							when ByDay like '%Last%' then 'Last'
						end + ' ' +
						case 
							when ByDay like '%Mon%' then 'Monday'
							when ByDay like '%Tue%' then 'Tuesday'
							when ByDay like '%Wed%' then 'Wednesday'
							when ByDay like '%Thur%' then 'Thursday'
							when ByDay like '%Fri%' then 'Friday'
							when ByDay like '%Saturday%' then 'Saturday'
							when ByDay like '%Sun%' then 'Sunday'
							when ByDay like '%WeekDay%' then 'Weekday'
							when ByDay like '%Weekend%' then 'Weekend'
							when ByDay like 'Day' then 'Day'
						end
				end ByDay,
				case when ByDate between 1 and 31 then ByDate end ByDate,
				SubDayFrequency,
				case when SubDayFrequency = 'Second' and @SubDayInterval < 10 then 10 else @SubDayInterval end SubDayInterval,
				isnull(@StartTime, '00:00:00') StartTime,
				isnull(@EndTime, '23:59:59') EndTime,
				isnull(@StartDate, '1900-01-01') StartDate,
				isnull(@EndDate, '9999-12-31') EndDate
		from x0
	),
	x2 as
	(
		select	
			x1.Frequency, x1.Interval, 
			x1.ByDay, 
			case when x1.ByDay is null then x1.ByDate end ByDate, 
			x1.SubDayFrequency, x1.SubDayInterval, x1.StartTime, x1.EndTime, x1.StartDate, x1.EndDate
		from x1
	)
	select	
			x2.Frequency, x2.Interval, 
			x2.ByDay, 
			case when x2.ByDay is null then x2.ByDate end ByDate, 
			x2.SubDayFrequency, x2.SubDayInterval, x2.StartTime, x2.EndTime, x2.StartDate, x2.EndDate,
			case x2.Frequency
				when 'Once' then 'once at ' + convert(varchar(50), StartDate, 121) + ' ' + convert(varchar(50), StartTime, 121)
				when 'Agent Start' then 'when Agent Starts'
				when 'Idle' then 'when computer is idle'
				when 'Daily' then 
					case 
						when Interval = 1 then 'every day'
						else 'every' + cast(Interval as varchar(50)) + ' days'
					end 
				when 'Weekly' then 
					case 
						when Interval = 1 then 'every week'
						else 'every' + cast(Interval as varchar(50)) + ' weeks'
					end + ' on ' + replace(ByDate, ',', ', ')
				when 'Monthly' then 
					case 
						when Interval = 1 then 'every month'
						else 'every' + cast(Interval as varchar(50)) + ' months'
					end + ' on ' +
					case 
						when ByDate is not null then 'day ' + cast(ByDate as varchar(50))
						else ByDate
					end
			end 
			+  
			case when x2.Frequency in ('Daily', 'Weekly', 'Monthly') then
					case SubDayFrequency
						when 'Once' then ' at ' + convert(varchar(50), StartTime, 121)
						when 'Hourly' then  ' every ' + cast(SubDayInterval as varchar(50)) +  ' hour' + case when SubDayInterval > 1 then 's' else '' end + case when StartTime = '00:00:00' and EndTime = '23:59:59' then '' else ' between ' + convert(varchar(50), StartTime, 121) + ' and ' + convert(varchar(50), EndTime, 121) end
						when 'Minute' then  ' every ' + cast(SubDayInterval as varchar(50)) +  ' minute' + case when SubDayInterval > 1 then 's' else '' end + case when StartTime = '00:00:00' and EndTime = '23:59:59' then '' else ' between ' + convert(varchar(50), StartTime, 121) + ' and ' + convert(varchar(50), EndTime, 121) end
						when 'Second' then  ' every ' + cast(SubDayInterval as varchar(50)) +  ' second' + case when SubDayInterval > 1 then 's' else '' end + case when StartTime = '00:00:00' and EndTime = '23:59:59' then '' else ' between ' + convert(varchar(50), StartTime, 121) + ' and ' + convert(varchar(50), EndTime, 121) end
					end
					+ 
					case 
						when StartDate <= '1900-01-01' and EndDate >= '9999-12-31' then ''
						when StartDate <= '1900-01-01' and EndDate < '9999-12-31' then '. Schedule will be used until ' + convert(varchar(50), EndDate, 121)
						when StartDate > '1900-01-01' and EndDate >= '9999-12-31' then '. Schedule will be used starting on ' + convert(varchar(50), StartDate, 121)
						when StartDate > '1900-01-01' and EndDate < '9999-12-31' then '. Schedule will be used between ' + convert(varchar(50), StartDate, 121) + ' and ' + convert(varchar(50), EndDate, 121)
					end
					
				else ''
			end
			as Description
	from x2
)