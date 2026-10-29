create or alter procedure z.usp_CollectCPUMemoryStats
as
begin
	set nocount, xact_abort on;
	set transaction isolation level read committed;
	declare @LockResult int;

	begin tran;
	begin try
		exec @LockResult = sys.sp_getapplock @Resource = N'z.usp_CollectCPUMemoryStats', @LockMode = 'Exclusive', @LockOwner = 'Transaction', @LockTimeout = 10000;
		if @LockResult < 0 throw 51000, 'Unable to acquire the CPU and memory collection lock.', 1;

		;with x as
		(
			select d.Date, v.SystemIdle, v.SQLProcessUtilization, v.Other, v.UserModeTime, v.KernelModeTime,
				v.PageFaults, v.WorkingSetDelta, v.MemoryUtilizationPercentage,
				row_number() over(partition by d.Date order by v.Date desc) RecordOrdinal
			from z.v_CPUMemoryStats v
				cross apply (values(dateadd(millisecond, -datepart(millisecond, v.Date), v.Date))) d(Date)
		),
		s as
		(
			select Date, SystemIdle, SQLProcessUtilization, Other, UserModeTime, KernelModeTime,
				PageFaults, WorkingSetDelta, MemoryUtilizationPercentage
			from x
			where RecordOrdinal = 1
		)
		merge z.CPUMemoryStats with (holdlock) as t using s on t.Date = s.Date
		when matched then
			update set SystemIdle = s.SystemIdle, SQLProcessUtilization = s.SQLProcessUtilization, Other = s.Other, UserModeTime = s.UserModeTime, KernelModeTime = s.KernelModeTime, PageFaults = s.PageFaults, WorkingSetDelta = s.WorkingSetDelta, MemoryUtilizationPercentage = s.MemoryUtilizationPercentage
		when not matched by target then
			insert (Date, SystemIdle, SQLProcessUtilization, Other, UserModeTime, KernelModeTime, PageFaults, WorkingSetDelta, MemoryUtilizationPercentage)
			values (s.Date, s.SystemIdle, s.SQLProcessUtilization, s.Other, s.UserModeTime, s.KernelModeTime, s.PageFaults, s.WorkingSetDelta, s.MemoryUtilizationPercentage);
		commit;
	end try
	begin catch
		if @@trancount > 0 rollback;
		throw;
	end catch
end
