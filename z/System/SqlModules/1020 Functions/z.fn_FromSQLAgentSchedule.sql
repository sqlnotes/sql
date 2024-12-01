create or alter function z.fn_FromSQLAgentSchedule
(
	@freq_type int,
	@freq_interval int,
	@freq_subday_type int,
	@freq_subday_interval int,
	@freq_relative_interval int,
	@freq_recurrence_factor int,
	@active_start_date int,
	@active_end_date int,
	@active_start_time int,
	@active_end_time int
)
returns table
as
return 
(
	select	
			*
	from z.fn_CleanseScheduleParameter(
			case @freq_type
				when 1 then 'Specific'
				when 4 then 'Daily'
				when 8 then 'Weekly'
				when 16 then 'Monthly'
				when 32 then 'Monthly'
				when 64 then 'Agent Starts'
				when 128 then 'Idle'
			end /*Frequency*/,
			case 
				when @freq_type = 4 then @freq_interval --'Daily'
				when @freq_type in (8, 16, 32) then @freq_recurrence_factor -- Weekly, Monthly
			end /*Interval*/, 
			case @freq_type
				when 1 then convert( varchar(100), convert(date, cast(@active_start_date as varchar), 112), 121) + ' ' +  cast(z.fn_SQLAgentScheduleTimeToTime(isnull(@active_start_time, 0)) as varchar(100)) -- Specific
				when 8 then 
					stuff(
							case when @freq_interval & 1 = 1 then ',Sunday' else '' end + 
							case when @freq_interval & 2 = 2 then ',Monday' else '' end + 
							case when @freq_interval & 4 = 4 then ',Tuesday' else '' end + 
							case when @freq_interval & 8 = 8 then ',WednesDay' else '' end + 
							case when @freq_interval & 16 = 16 then ',Thursday' else '' end + 
							case when @freq_interval & 32 = 32 then ',Friday' else '' end + 
							case when @freq_interval & 64 = 64 then ',Sunday' else '' end
						, 1, 1, '')--Weekly
				when 16 then cast(@freq_interval as varchar(100))
				when 32 then --'Monthly relative'
					case @freq_relative_interval 
						when 1 then 'First'
						when 2 then 'Second'
						when 4 then 'Third'
						when 8 then 'Fourth'
						when 16 then 'Last'
					end + ' ' +
					case @freq_interval
						when 1 then 'Sunday'
						when 2 then 'Monday'
						when 3 then 'Tuesday'
						when 4 then 'Wednesday'
						when 5 then 'Thursday'
						when 6 then 'Friday'
						when 7 then 'Saturday'
						when 8 then 'Day'
						when 9 then 'Weekday'
						when 10 then 'Weekend'
					end
			end /*ByDay*/,
			case @freq_subday_type
				when 1 then 'Specific'
				when 2 then 'Second'
				when 4 then 'Minute'
				when 8 then 'Hourly'
			end /*IntradayFrequency*/,
			@freq_subday_interval /*IntradayInterval*/,
			case 
				when @freq_subday_type = 1 then cast(z.fn_SQLAgentScheduleTimeToTime(isnull(@active_start_time, 0)) as varchar(100))
				else cast(z.fn_SQLAgentScheduleTimeToTime(isnull(@active_start_time, 0)) as varchar(100)) + '-' + cast(z.fn_SQLAgentScheduleTimeToTime(isnull(@active_end_time, 235959)) as varchar(100)) 
			end /*ByTime*/,
			convert(date, cast(@active_start_date as varchar(10)), 112) /*StartDate*/,
			convert(date, cast(@active_end_date as varchar(10)), 112) /*EndDate*/
		) a

)
