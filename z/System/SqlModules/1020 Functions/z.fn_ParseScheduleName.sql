create or alter function z.fn_ParseScheduleName
(
	@ScheduleName varchar(128)
)
returns table
as
return
(
	with x0 as
	(
		select iif(left(@ScheduleName, 10) = 'Schema z: ', 1, 0) IsSchedule, stuff(@ScheduleName, 1, 10, '') Schedule
	),
	x1 as
	(
		select s.Ordinal, try_cast(s.Value as int) Value
		from x0
			cross apply z.fn_SplitString(Schedule, '-') s
		where isnull(x0.IsSchedule, 0) = 1
	),
	x2 as
	(
		select [1] freq_type, [2] freq_interval, [3] freq_subday_type, [4] freq_subday_interval, [5] freq_relative_interval, [6] freq_recurrence_factor, [7] active_start_date, [8] active_end_date, [9] active_start_time, [10] active_end_time
		from x1
		pivot
		(
			max(Value)
			for Ordinal in ([1], [2], [3], [4], [5], [6], [7], [8], [9], [10])
		) pvt
	)
	select s.ScheduleID, s.Frequency, s.Interval, s.ByDay, s.IntradayFrequency, s.IntradayInterval, s.ByTime, s.StartDate, s.EndDate, s.Description
	from x2
		cross apply z.fn_FromSQLAgentSchedule(x2.freq_type, x2.freq_interval, x2.freq_subday_type, x2.freq_subday_interval, x2.freq_relative_interval, x2.freq_recurrence_factor, x2.active_start_date, x2.active_end_date, x2.active_start_time, x2.active_end_time) s
	where x2.freq_type is not null and x2.freq_interval is not null 
		and x2.freq_subday_type is not null and x2.freq_subday_interval is not null 
		and x2.freq_relative_interval is not null and x2.freq_recurrence_factor is not null 
		and x2.active_start_date is not null and x2.active_end_date is not null 
		and x2.active_start_time is not null and x2.active_end_time is not null
)
