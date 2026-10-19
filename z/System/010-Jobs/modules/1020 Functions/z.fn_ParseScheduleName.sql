create or alter function z.fn_ParseScheduleName
(
	@ScheduleName nvarchar(128)
)
returns table
as
return
(
	with n0 as
	(
		select charindex(N' :', reverse(@ScheduleName)) SeparatorPosition
	),
	n1 as
	(
		select left(@ScheduleName, len(@ScheduleName) - iif(SeparatorPosition > 0, SeparatorPosition - 1, 0)) Prefix,
			right(@ScheduleName, iif(SeparatorPosition > 0, SeparatorPosition - 1, 0)) Schedule
		from n0
	),
	n2 as
	(
		select Prefix, Schedule, len(Prefix + N'#') - 1 PrefixLength
		from n1
	),
	x0 as
	(
		select case
			when Prefix = N'Schema z: ' then 1
			when left(Prefix, 11) = N'Schema z: [' and right(Prefix, 3) = N']: '
				and substring(Prefix, 11, iif(PrefixLength >= 12, PrefixLength - 12, 0)) =
					quotename(replace(substring(Prefix, 12, iif(PrefixLength >= 14, PrefixLength - 14, 0)), N']]', N']')) then 1
			else 0 end IsSchedule, Schedule
		from n2
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
		and (select count(*) from x1) = 10
		and x2.freq_subday_type is not null and x2.freq_subday_interval is not null 
		and x2.freq_relative_interval is not null and x2.freq_recurrence_factor is not null 
		and x2.active_start_date is not null and x2.active_end_date is not null 
		and x2.active_start_time is not null and x2.active_end_time is not null
)
