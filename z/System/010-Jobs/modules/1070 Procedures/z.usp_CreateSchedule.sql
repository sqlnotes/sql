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
	@ScheduleNames nvarchar(max) = null output,
	@ScheduleIDs nvarchar(max) = null output,
	@OperationDate date = null -- Nested callers pass their captured server-local date.
)
as
begin
	set nocount, xact_abort on
	declare @Today date = isnull(@OperationDate, convert(date, getdate()));
	select @StartDate = isnull(@StartDate, @Today);
	declare @ValidationError nvarchar(4000) = z.fn_ValidateScheduleParameter(@Frequency, @Interval, @ByDay, @IntradayFrequency, @IntradayInterval, @ByTime, @StartDate, @EndDate);
	select @ScheduleNames = null, @ScheduleIDs = null;
	if @ValidationError is not null throw 51000, @ValidationError, 1;
	create table #DesiredSchedules
	(
		ScheduleRow int identity primary key, ScheduleID int null, ResolvedName sysname null,
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
			@ScheduleRow int, @ScheduleID int, @AddResult int, @TodayInt int = convert(int, convert(char(8), @Today, 112)),
			@Prefix nvarchar(300) = z.fn_GetScheduleNamePrefix(), @PrefixLength int, @c cursor, @Resource nvarchar(255) = z.fn_ResourceSQLScheduleOperation(), @LockResult int, @DriftScheduleName sysname, @MismatchMessage nvarchar(2048)
	select @PrefixLength = len(@Prefix collate Latin1_General_100_BIN2 + N'#') - 1;
	begin try
	set @c  = cursor local static for
		select ScheduleRow, Name, freq_type, freq_interval, freq_subday_type, freq_subday_interval, freq_relative_interval, freq_recurrence_factor, active_start_date, active_end_date, active_start_time, active_end_time
		from #DesiredSchedules order by ScheduleRow
	open @c
	if @@cursor_rows =0
		throw 51000, 'The schedule definition did not produce any schedules; database-prefixed schedule names must fit the 128-character limit.', 1;
	begin tran
	exec @LockResult = sys.sp_getapplock @Resource = @Resource, @LockMode = N'Exclusive', @LockOwner = N'Transaction', @LockTimeout = 15000;
	if @LockResult < 0 throw 51001, 'Could not acquire the database schedule operation lock.', 1;
	insert into #ExistingSchedules(schedule_id, schedule_uid, schedule_name, enabled, freq_type, freq_interval, freq_subday_type, freq_subday_interval, freq_relative_interval, freq_recurrence_factor, active_start_date, active_end_date, active_start_time, active_end_time, date_created, schedule_description, job_count)
		exec msdb.dbo.sp_help_schedule -- do not directly access tables in MSDB, no access on AWS RDS.
	-- Check the whole requested set before creating any schedules. Enabled state is operator-owned.
	-- Parse owned numeric names without losing unused native timing fields.
	select e.schedule_id, e.schedule_name,
		try_convert(int, json_value(j.Definition, '$[0]')) freq_type,
		try_convert(int, json_value(j.Definition, '$[1]')) freq_interval,
		try_convert(int, json_value(j.Definition, '$[2]')) freq_subday_type,
		try_convert(int, json_value(j.Definition, '$[3]')) freq_subday_interval,
		try_convert(int, json_value(j.Definition, '$[4]')) freq_relative_interval,
		try_convert(int, json_value(j.Definition, '$[5]')) freq_recurrence_factor,
		try_convert(int, json_value(j.Definition, '$[6]')) active_start_date,
		try_convert(int, json_value(j.Definition, '$[7]')) active_end_date,
		try_convert(int, json_value(j.Definition, '$[8]')) active_start_time,
		case when try_convert(int, json_value(j.Definition, '$[9]')) = 0 then 235959
			else try_convert(int, json_value(j.Definition, '$[9]')) end active_end_time,
		(select count(*) from openjson(j.Definition)) FieldCount
	into #OwnedSchedules
	from #ExistingSchedules e
		cross apply (select N'["' + replace(string_escape(substring(e.schedule_name collate Latin1_General_100_BIN2, @PrefixLength + 1, 128), 'json'), N'-', N'","') + N'"]' Definition) j
	where left(e.schedule_name collate Latin1_General_100_BIN2, @PrefixLength) = @Prefix collate Latin1_General_100_BIN2;

	-- Candidates qualify by their actual fields or their encoded fields. The latter
	-- catches shared schedules whose timing drifted away from the requested pattern.
	select distinct d.ScheduleRow, e.schedule_id
	into #Candidates
	from #DesiredSchedules d
		cross join #OwnedSchedules o
		join #ExistingSchedules e on e.schedule_id = o.schedule_id
		cross apply
		(
			select e.freq_type, e.freq_interval, e.freq_subday_type, e.freq_subday_interval, e.freq_relative_interval,
				e.freq_recurrence_factor, e.active_start_date, e.active_end_date, e.active_start_time, e.active_end_time
			union all
			select o.freq_type, o.freq_interval, o.freq_subday_type, o.freq_subday_interval, o.freq_relative_interval,
				o.freq_recurrence_factor, o.active_start_date, o.active_end_date, o.active_start_time, o.active_end_time
			where o.FieldCount = 10
		) p
	where p.freq_type = d.freq_type and p.freq_interval = d.freq_interval
		and p.freq_subday_type = d.freq_subday_type and p.freq_subday_interval = d.freq_subday_interval
		and p.freq_relative_interval = d.freq_relative_interval and p.freq_recurrence_factor = d.freq_recurrence_factor
		and p.active_end_date = d.active_end_date and p.active_start_time = d.active_start_time
		and p.active_end_time = case when d.active_end_time = 0 then 235959 else d.active_end_time end
		and (p.active_start_date = d.active_start_date or (d.freq_type = 4 and d.freq_interval = 1
			and p.active_start_date <= @TodayInt and d.active_start_date <= @TodayInt));

	select top (1) @DriftScheduleName = e.schedule_name
	from #ExistingSchedules e
		join #OwnedSchedules o on o.schedule_id = e.schedule_id
	where
		(exists(select 1 from #DesiredSchedules d where e.schedule_name collate Latin1_General_100_BIN2 = d.Name collate Latin1_General_100_BIN2)
			or exists(select 1 from #Candidates c where c.schedule_id = e.schedule_id))
		and
		(
			o.FieldCount <> 10 or exists
			(
				select e.freq_type, e.freq_interval, e.freq_subday_type, e.freq_subday_interval, e.freq_relative_interval,
					e.freq_recurrence_factor, e.active_start_date, e.active_end_date, e.active_start_time, e.active_end_time
				except
				select o.freq_type, o.freq_interval, o.freq_subday_type, o.freq_subday_interval, o.freq_relative_interval,
					o.freq_recurrence_factor, o.active_start_date, o.active_end_date, o.active_start_time, o.active_end_time
			)
		)
	order by e.schedule_id;
	if @DriftScheduleName is not null
	begin
		select @MismatchMessage = replace(N'Existing schedule "' + @DriftScheduleName + N'" has timing settings that differ from its generated name. Restore its timing settings or rename it before retrying.', N'%', N'%%');
		throw 51000, @MismatchMessage, 1;
	end;
	update d set ScheduleID = r.schedule_id, ResolvedName = r.schedule_name
	from #DesiredSchedules d
		cross apply
		(
			select top (1) e.schedule_id, e.schedule_name
			from #Candidates c
				join #ExistingSchedules e on e.schedule_id = c.schedule_id
			where c.ScheduleRow = d.ScheduleRow
			order by case when e.active_start_date = d.active_start_date then 0 else 1 end, e.schedule_id
		) r;
	fetch next from @c into @ScheduleRow, @Name, @freq_type, @freq_interval, @freq_subday_type, @freq_subday_interval, @freq_relative_interval, @freq_recurrence_factor, @active_start_date, @active_end_date, @active_start_time, @active_end_time
	while @@fetch_status = 0
	begin
		select @ScheduleID = ScheduleID from #DesiredSchedules where ScheduleRow = @ScheduleRow;
		if @ScheduleID is null
		begin
			exec @AddResult = msdb.dbo.sp_add_schedule @schedule_name = @name, @enabled = 1, @freq_type = @freq_type, @freq_interval = @freq_interval, @freq_subday_type = @freq_subday_type, @freq_subday_interval = @freq_subday_interval, @freq_relative_interval= @freq_relative_interval, @freq_recurrence_factor = @freq_recurrence_factor, @active_start_date = @active_start_date, @active_end_date = @active_end_date, @active_start_time = @active_start_time, @active_end_time = @active_end_time, @schedule_id = @ScheduleID output
			if isnull(@AddResult, 1) <> 0 or isnull(@ScheduleID, 0) <= 0
				throw 51000, 'SQL Agent did not return a schedule ID for the new schedule.', 1;
			update #DesiredSchedules set ScheduleID = @ScheduleID, ResolvedName = @Name where ScheduleRow = @ScheduleRow;
		end
		fetch next from @c into @ScheduleRow, @Name, @freq_type, @freq_interval, @freq_subday_type, @freq_subday_interval, @freq_relative_interval, @freq_recurrence_factor, @active_start_date, @active_end_date, @active_start_time, @active_end_time
	end
	close @c
	deallocate @c
	select @ScheduleNames = string_agg(convert(nvarchar(max), ResolvedName), N',') within group(order by ScheduleID),
		@ScheduleIDs = N'[' + string_agg(convert(nvarchar(max), ScheduleID), N',') within group(order by ScheduleID) + N']'
	from (select distinct ScheduleID, ResolvedName from #DesiredSchedules) r;
	commit
	end try
	begin catch
		select @ScheduleNames = null, @ScheduleIDs = null;
		if @@trancount > 0
			rollback;
		throw;
	end catch
end
go
