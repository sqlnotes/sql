if z.fn_IsSQLAgentRunning() = 0 -- agent is not running
	raiserror('agent is not running', 16, 1)
go
set nocount on

go
if not exists(
				select * 
				from z.fn_CleanseScheduleParameter('once', 1, '3025-12-31','second', 1, '06:00', '2024-01-01', '2025-01-01')
				where Frequency = 'Specific' and Interval is null and ByDay = '3025-12-31 00:00:00'
					and IntradayFrequency is null and IntradayInterval is null and ByTime is null
					and StartDate = '3025-12-31' and EndDate = '9999-12-31'
					and Description = 'at time 3025-12-31 00:00:00'
			)
begin
	raiserror('z.fn_CleanseScheduleParameter: Test 1 failed', 16, 1)
end
go

if exists(select * from z.fn_CleanseScheduleParameter('Monthly, daily', 1, '1stmon, 1, 2, 3, last sat, last day','second', 1, '06:00', '2024-01-01', '2025-01-01'))
begin
	raiserror('z.fn_CleanseScheduleParameter: Test 2 failed', 16, 1)
end
go
if not exists(
				select * 
				from z.fn_CleanseScheduleParameter('m', 1, '1stmon, 1, 2, 3, last sat, last day, 32','second', 1, '06:00-13:00', '2024-01-01', '2025-01-01')
				where Frequency = 'Monthly' and Interval = 1 and ByDay = '1,2,3,First Monday,Last Saturday,Last Day'
					and IntradayFrequency ='Second' and IntradayInterval = 10 and ByTime = '06:00:00-13:00:00'
					and StartDate = '2024-01-01' and EndDate = '2025-01-01'
					and Description = 'every month on 1, 2, 3, First Monday, Last Saturday, Last Day every 10 seconds between 06:00:00 and 13:00:00 from 2024-01-01 to 2025-01-01'
			)
begin
	raiserror('z.fn_CleanseScheduleParameter: Test 3 failed', 16, 1)
end
go
if not exists(
				select * 
				from z.fn_CleanseScheduleParameter('weekly', 2, '1stmon, 1, 2, 3, last sat, last day','m', 6, '06:00', '2024-01-01', '2025-01-01')
				where Frequency = 'Weekly' and Interval = 2 and ByDay = 'Monday,Tuesday,Wednesday,Saturday'
					and IntradayFrequency ='Minute' and IntradayInterval = 6 and ByTime = '06:00:00-05:59:59'
					and StartDate = '2024-01-01' and EndDate = '2025-01-01'
					and Description = 'every 2 weeks on Monday, Tuesday, Wednesday, Saturday every 6 minutes between 06:00:00 and 05:59:59 from 2024-01-01 to 2025-01-01'
			)
begin
	raiserror('z.fn_CleanseScheduleParameter: Test 4 failed', 16, 1)
end
go
if not exists(
				select * 
				from z.fn_CleanseScheduleParameter('d', 2, '1stmon, 1, 2, 3, last sat, last day','m', 6, '06:00', '2024-01-01', '2025-01-01')
				where Frequency = 'Daily' and Interval = 2 and ByDay is null
					and IntradayFrequency ='Minute' and IntradayInterval = 6 and ByTime = '06:00:00-05:59:59'
					and StartDate = '2024-01-01' and EndDate = '2025-01-01'
					and Description = 'every 2 days every 6 minutes between 06:00:00 and 05:59:59 from 2024-01-01 to 2025-01-01'
			)
begin
	raiserror('z.fn_CleanseScheduleParameter: Test 5 failed', 16, 1)
end
go
if not exists(
				select * 
				from z.fn_CleanseScheduleParameter('weekly', 2, '1stmon, 1, 2, 3, last sat, last day, 8','m', 6, '06:00, 16:30', '2024-01-01', '2025-01-01')
				where Frequency = 'Weekly' and Interval = 2 and ByDay = 'Monday,Tuesday,Wednesday,Saturday'
					and IntradayFrequency ='Minute' and IntradayInterval = 6 and ByTime = '06:00:00-05:59:59,16:30:00-16:29:59'
					and StartDate = '2024-01-01' and EndDate = '2025-01-01'
					and Description = 'every 2 weeks on Monday, Tuesday, Wednesday, Saturday every 6 minutes between 06:00:00 and 05:59:59, 16:30:00 and 16:29:59 from 2024-01-01 to 2025-01-01'
			)
begin
	raiserror('z.fn_CleanseScheduleParameter: Test 6 failed', 16, 1)
end
go
if exists(
			select * 
			from z.fn_CleanseScheduleParameter(null, 1, '3025-12-31','second', 1, '06:00', '2024-01-01', '2025-01-01')
			where Frequency = 'Specific' and Interval is null and ByDay = '3025-12-31 00:00:00'
				and IntradayFrequency is null and IntradayInterval is null and ByTime is null
				and StartDate = '1900-01-01' and EndDate = '9999-12-31'
				and Description = 'at time 3025-12-31 00:00:00'
		)
begin
	raiserror('z.fn_CleanseScheduleParameter: Test 7 failed', 16, 1)
end
go
if (
		select count(8)
		from z.fn_ToSQLAgentSchedule('weekly', 2, '1stmon, 1, 2, 3, last sat, last day','m', 6, '06:00, 16:30', '2024-01-01', '2025-01-01')
	) <> 2
	raiserror('z.fn_ToSQLAgentSchedule: Test 1 failed', 16, 1)
go
if (
	select count(* )
	from z.fn_ToSQLAgentSchedule('Monthly', 2, '1stmon, 1, 2, 3, last sat, last day','m', 6, '06:00, 16:30', '2024-01-01', '2025-01-01')
	) <> 12
	raiserror('z.fn_ToSQLAgentSchedule: Test 2 failed', 16, 1)
go
if (
	select count(*)
	from z.fn_ToSQLAgentSchedule('once', 1, '3025-12-31','second', 1, '06:00', '2024-01-01', '2025-01-01')
	) <> 1
	raiserror('z.fn_ToSQLAgentSchedule: Test 3 failed', 16, 1)
go
----end to end test
exec z.usp_DropAllLocalTempTables
go
declare @i int, @j int, @k int
create table #1(id int identity(1,1) ,freq_type int, freq_interval int, freq_subday_type int, freq_subday_interval int, freq_relative_interval int, freq_recurrence_factor int, active_start_date int, active_end_date int, active_start_time int, active_end_time int)

insert into #1 (freq_type, freq_interval, freq_subday_type, freq_subday_interval, freq_relative_interval, freq_recurrence_factor, active_start_date, active_start_time, active_end_date, active_end_time)
	--once
	select 1 freq_type, 0 freq_interval, 0 freq_subday_type, 0 freq_subday_interval, 0 freq_relative_interval, 0 freq_recurrence_factor, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'yyyyMMdd') as int) active_start_date, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'hhmmss') as int) active_start_time, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'yyyyMMdd') as int) active_end_date, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'hhmmss') as int) active_end_time
	union all
	-- Daily
	select 4 freq_type, 3 freq_interval, 1 freq_subday_type, 10 freq_subday_interval, 0 freq_relative_interval, 0 freq_recurrence_factor, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'yyyyMMdd') as int) active_start_date, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'hhmmss') as int) active_start_time, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'yyyyMMdd') as int) active_end_date, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'hhmmss') as int) active_end_time
	union all
	select 4 freq_type, 3 freq_interval, 2 freq_subday_type, 10 freq_subday_interval, 0 freq_relative_interval, 0 freq_recurrence_factor, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'yyyyMMdd') as int) active_start_date, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'hhmmss') as int) active_start_time, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'yyyyMMdd') as int) active_end_date, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'hhmmss') as int) active_end_time
	union all
	select 4 freq_type, 3 freq_interval, 4 freq_subday_type, 10 freq_subday_interval, 0 freq_relative_interval, 0 freq_recurrence_factor, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'yyyyMMdd') as int) active_start_date, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'hhmmss') as int) active_start_time, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'yyyyMMdd') as int) active_end_date, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'hhmmss') as int) active_end_time
	union all
	select 4 freq_type, 3 freq_interval, 8 freq_subday_type, 10 freq_subday_interval, 0 freq_relative_interval, 0 freq_recurrence_factor, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'yyyyMMdd') as int) active_start_date, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'hhmmss') as int) active_start_time, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'yyyyMMdd') as int) active_end_date, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'hhmmss') as int) active_end_time

	union all

	-- weekly
	select 8 freq_type, 1 freq_interval, 1 freq_subday_type, 11 freq_subday_interval, 0 freq_relative_interval, 2 freq_recurrence_factor, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'yyyyMMdd') as int) active_start_date, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'hhmmss') as int) active_start_time, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'yyyyMMdd') as int) active_end_date, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'hhmmss') as int) active_end_time
	union all
	select 8 freq_type, 1 freq_interval, 2 freq_subday_type, 11 freq_subday_interval, 0 freq_relative_interval, 2 freq_recurrence_factor, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'yyyyMMdd') as int) active_start_date, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'hhmmss') as int) active_start_time, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'yyyyMMdd') as int) active_end_date, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'hhmmss') as int) active_end_time
	union all
	select 8 freq_type, 1 freq_interval, 4 freq_subday_type, 11 freq_subday_interval, 0 freq_relative_interval, 2 freq_recurrence_factor, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'yyyyMMdd') as int) active_start_date, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'hhmmss') as int) active_start_time, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'yyyyMMdd') as int) active_end_date, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'hhmmss') as int) active_end_time
	union all
	select 8 freq_type, 1 freq_interval, 8 freq_subday_type, 11 freq_subday_interval, 0 freq_relative_interval, 2 freq_recurrence_factor, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'yyyyMMdd') as int) active_start_date, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'hhmmss') as int) active_start_time, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'yyyyMMdd') as int) active_end_date, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'hhmmss') as int) active_end_time

	select @i = 1
	while(@i < 65)
	begin
		insert into #1 (freq_type, freq_interval, freq_subday_type, freq_subday_interval, freq_relative_interval, freq_recurrence_factor, active_start_date, active_start_time, active_end_date, active_end_time)
			select 8 freq_type, @i freq_interval, 1 freq_subday_type, 11 freq_subday_interval, 0 freq_relative_interval, 2 freq_recurrence_factor, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'yyyyMMdd') as int) active_start_date, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'hhmmss') as int) active_start_time, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'yyyyMMdd') as int) active_end_date, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'hhmmss') as int) active_end_time
			union all
			select 8 freq_type, @i freq_interval, 2 freq_subday_type, 11 freq_subday_interval, 0 freq_relative_interval, 2 freq_recurrence_factor, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'yyyyMMdd') as int) active_start_date, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'hhmmss') as int) active_start_time, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'yyyyMMdd') as int) active_end_date, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'hhmmss') as int) active_end_time
			union all
			select 8 freq_type, @i freq_interval, 4 freq_subday_type, 11 freq_subday_interval, 0 freq_relative_interval, 2 freq_recurrence_factor, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'yyyyMMdd') as int) active_start_date, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'hhmmss') as int) active_start_time, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'yyyyMMdd') as int) active_end_date, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'hhmmss') as int) active_end_time
			union all
			select 8 freq_type, @i freq_interval, 8 freq_subday_type, 11 freq_subday_interval, 0 freq_relative_interval, 2 freq_recurrence_factor, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'yyyyMMdd') as int) active_start_date, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'hhmmss') as int) active_start_time, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'yyyyMMdd') as int) active_end_date, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'hhmmss') as int) active_end_time
		select @i = @i +1
	end

	-- Monthly 1
	select @i = 1
	while(@i<32)
	begin
			insert into #1 (freq_type, freq_interval, freq_subday_type, freq_subday_interval, freq_relative_interval, freq_recurrence_factor, active_start_date, active_start_time, active_end_date, active_end_time)
				select 16 freq_type, @i freq_interval, 1 freq_subday_type, 0 freq_subday_interval, 0 freq_relative_interval, 2 freq_recurrence_factor, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'yyyyMMdd') as int) active_start_date, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'hhmmss') as int) active_start_time, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'yyyyMMdd') as int) active_end_date, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'hhmmss') as int) active_end_time
				union all
				select 16 freq_type, @i freq_interval, 2 freq_subday_type, 11 freq_subday_interval, 0 freq_relative_interval, 2 freq_recurrence_factor, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'yyyyMMdd') as int) active_start_date, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'hhmmss') as int) active_start_time, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'yyyyMMdd') as int) active_end_date, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'hhmmss') as int) active_end_time
				union all
				select 16 freq_type, @i freq_interval, 4 freq_subday_type, 11 freq_subday_interval, 0 freq_relative_interval, 2 freq_recurrence_factor, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'yyyyMMdd') as int) active_start_date, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'hhmmss') as int) active_start_time, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'yyyyMMdd') as int) active_end_date, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'hhmmss') as int) active_end_time
				union all
				select 16 freq_type, @i freq_interval, 8 freq_subday_type, 11 freq_subday_interval, 0 freq_relative_interval, 2 freq_recurrence_factor, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'yyyyMMdd') as int) active_start_date, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'hhmmss') as int) active_start_time, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'yyyyMMdd') as int) active_end_date, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'hhmmss') as int) active_end_time
		select @i = @i +1
	end

	-- Monthly 2
	select @i = 1
	while(@i<11)
	begin
		select @j = 0
		while @j < 5
		begin
			select @k = power(2, @j)
			insert into #1 (freq_type, freq_interval, freq_subday_type, freq_subday_interval, freq_relative_interval, freq_recurrence_factor, active_start_date, active_start_time, active_end_date, active_end_time)
				select 32 freq_type, @i freq_interval, 1 freq_subday_type, 0 freq_subday_interval, @k freq_relative_interval, 2 freq_recurrence_factor, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'yyyyMMdd') as int) active_start_date, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'hhmmss') as int) active_start_time, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'yyyyMMdd') as int) active_end_date, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'hhmmss') as int) active_end_time
				union all
				select 32 freq_type, @i freq_interval, 2 freq_subday_type, 11 freq_subday_interval, @k freq_relative_interval, 2 freq_recurrence_factor, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'yyyyMMdd') as int) active_start_date, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'hhmmss') as int) active_start_time, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'yyyyMMdd') as int) active_end_date, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'hhmmss') as int) active_end_time
				union all
				select 32 freq_type, @i freq_interval, 4 freq_subday_type, 11 freq_subday_interval, @k freq_relative_interval, 2 freq_recurrence_factor, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'yyyyMMdd') as int) active_start_date, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'hhmmss') as int) active_start_time, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'yyyyMMdd') as int) active_end_date, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'hhmmss') as int) active_end_time
				union all
				select 32 freq_type, @i freq_interval, 8 freq_subday_type, 11 freq_subday_interval, @k freq_relative_interval, 2 freq_recurrence_factor, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'yyyyMMdd') as int) active_start_date, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'hhmmss') as int) active_start_time, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'yyyyMMdd') as int) active_end_date, cast(format(z.fn_GenerateRandomDate(rand(), null, null), 'hhmmss') as int) active_end_time
			select @j = @j +1
		end
		select @i = @i + 1
	end

if exists(
			select a.*, b.*, c.*, d.*
			from #1 a
				outer apply z.fn_FromSQLAgentSchedule(a.freq_type, a.freq_interval, a.freq_subday_type, a.freq_subday_interval, a.freq_relative_interval, a.freq_recurrence_factor, a.active_start_date, a.active_end_date, a.active_start_time, a.active_end_time ) b	
				outer apply z.fn_ToSQLAgentSchedule(b.Frequency, b.Interval, b.ByDay, b.IntradayFrequency, b.IntradayInterval, b.ByTime, b.StartDate, b.EndDate) c
				outer apply z.fn_FromSQLAgentSchedule(c.freq_type, c.freq_interval, c.freq_subday_type, c.freq_subday_interval, c.freq_relative_interval, c.freq_recurrence_factor, c.active_start_date, c.active_end_date, c.active_start_time, c.active_end_time ) d
				outer apply z.fn_ParseScheduleName(c.Name) n
			where isnull(b.Description, '1') <> isnull(d.Description, '2')
				or isnull(n.Description, '1') <> isnull(d.Description, '2')
			)
	raiserror('SQL Agent Schedule transaction failed', 16, 1)



