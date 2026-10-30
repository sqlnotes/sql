create or alter procedure z.usp_CollectPerformanceCounters
(
	@Interval int = 1,
	@Duration int = 2147483647
)
as
begin
	set nocount, xact_abort on;
	set transaction isolation level read committed;
	if @Interval is null or @Interval <= 0 select @Interval = 1;
	if @Duration is null or @Duration <= 0 select @Duration = 2147483647;
	if @@trancount > 0 or (@@options & 2) = 2 throw 51000, 'Performance counter collection requires autocommit without an existing transaction.', 1;

	declare @LockResult int, @StartTicks bigint, @PreviousTicks bigint, @CurrentTicks bigint, @Deadline bigint,
		@TargetTicks bigint, @Remaining bigint, @WaitMilliseconds int, @Delay varchar(12), @Date datetime, @ElapsedSeconds float;
	create table #Current (ObjectName nvarchar(128) collate database_default not null, CounterName nvarchar(128) collate database_default not null, InstanceName nvarchar(128) collate database_default not null, CounterType int not null, RawValue bigint not null);
	create table #Previous (ObjectName nvarchar(128) collate database_default not null, CounterName nvarchar(128) collate database_default not null, InstanceName nvarchar(128) collate database_default not null, CounterType int not null, RawValue bigint not null);

	begin try
		select @StartTicks = ms_ticks from sys.dm_os_sys_info;
		select @Deadline = @StartTicks + convert(bigint, @Duration) * 1000;
		insert #Current (ObjectName, CounterName, InstanceName, CounterType, RawValue)
			select rtrim(ObjectName), rtrim(CounterName), rtrim(InstanceName), CounterType, CounterValue from z.v_PerformanceCountersDefault;
		select @PreviousTicks = ms_ticks from sys.dm_os_sys_info;

		while @PreviousTicks < @Deadline
		begin
			select @TargetTicks = @PreviousTicks + convert(bigint, @Interval) * 1000;
			if @TargetTicks > @Deadline select @TargetTicks = @Deadline;
			select @CurrentTicks = ms_ticks from sys.dm_os_sys_info;
			while @CurrentTicks < @TargetTicks
			begin
				select @Remaining = @TargetTicks - @CurrentTicks;
				select @WaitMilliseconds = convert(int, iif(@Remaining > 1000, 1000, @Remaining));
				select @Delay = convert(varchar(12), dateadd(millisecond, @WaitMilliseconds, cast('00:00:00' as time(3))), 114);
				waitfor delay @Delay;
				select @CurrentTicks = ms_ticks from sys.dm_os_sys_info;
			end

			truncate table #Previous;
			insert #Previous (ObjectName, CounterName, InstanceName, CounterType, RawValue)
				select ObjectName, CounterName, InstanceName, CounterType, RawValue from #Current;
			truncate table #Current;
			insert #Current (ObjectName, CounterName, InstanceName, CounterType, RawValue)
				select rtrim(ObjectName), rtrim(CounterName), rtrim(InstanceName), CounterType, CounterValue from z.v_PerformanceCountersDefault;
			select @CurrentTicks = ms_ticks, @Date = getutcdate() from sys.dm_os_sys_info;
			select @ElapsedSeconds = (@CurrentTicks - @PreviousTicks) / 1000.0;

			-- Match explicit ratio names or the conventional exact counter-name + Base name; absent bases remain NULL.
			begin tran;
			exec @LockResult = sys.sp_getapplock @Resource = N'z.usp_CollectPerformanceCounters', @LockMode = 'Exclusive', @LockOwner = 'Transaction', @LockTimeout = 10000;
			if @LockResult < 0 throw 51000, 'Unable to acquire the performance counter write lock.', 1;
			;with s as
			(
				select @Date Date, c.ObjectName, c.CounterName, c.InstanceName, c.CounterType,
					case
						when c.CounterType in (65792, 1073939712) then convert(float, c.RawValue)
						when c.CounterType in (272696320, 272696576) and c.RawValue >= p.RawValue
							then convert(float, convert(decimal(38, 0), c.RawValue) - convert(decimal(38, 0), p.RawValue)) / nullif(@ElapsedSeconds, 0)
						when c.CounterType = 537003264 and b.RawValue > 0
							then 100.0 * convert(float, c.RawValue) / convert(float, b.RawValue)
						when c.CounterType = 1073874176 and c.RawValue >= p.RawValue and b.RawValue > q.RawValue
							then convert(float, convert(decimal(38, 0), c.RawValue) - convert(decimal(38, 0), p.RawValue)) / nullif(convert(float, convert(decimal(38, 0), b.RawValue) - convert(decimal(38, 0), q.RawValue)), 0)
					end CounterValue,
					c.RawValue, b.RawValue BaseValue, @ElapsedSeconds ElapsedSeconds
				from #Current c
					left join #Previous p on p.ObjectName = c.ObjectName and p.CounterName = c.CounterName and p.InstanceName = c.InstanceName and p.CounterType = c.CounterType
					cross apply (values(case
						when c.CounterName = N'Worktables From Cache Ratio' then N'Worktables From Cache Base'
						when c.CounterName = N'Cache Hit Ratio' then N'Cache Hit Ratio Base'
						when c.CounterType in (537003264, 1073874176) then c.CounterName + N' Base'
					end)) n(BaseName)
					left join #Current b on b.ObjectName = c.ObjectName and b.CounterName = n.BaseName and b.InstanceName = c.InstanceName and b.CounterType = 1073939712
					left join #Previous q on q.ObjectName = b.ObjectName and q.CounterName = b.CounterName and q.InstanceName = b.InstanceName and q.CounterType = b.CounterType
			)
			merge z.PerformanceCounters with (holdlock) as t using s
				on t.Date = s.Date and t.ObjectName = s.ObjectName and t.CounterName = s.CounterName and t.InstanceName = s.InstanceName
			when matched then
				update set CounterType = s.CounterType, CounterValue = s.CounterValue, RawValue = s.RawValue, BaseValue = s.BaseValue, ElapsedSeconds = s.ElapsedSeconds
			when not matched by target then
				insert (Date, ObjectName, CounterName, InstanceName, CounterType, CounterValue, RawValue, BaseValue, ElapsedSeconds)
				values (s.Date, s.ObjectName, s.CounterName, s.InstanceName, s.CounterType, s.CounterValue, s.RawValue, s.BaseValue, s.ElapsedSeconds);
			commit;
			select @PreviousTicks = @CurrentTicks;
		end
	end try
	begin catch
		if @@trancount > 0 rollback;
		throw;
	end catch
end
