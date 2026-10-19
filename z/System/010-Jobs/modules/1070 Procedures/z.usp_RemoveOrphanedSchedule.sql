create or alter procedure z.usp_RemoveOrphanedSchedule
(
	@AllOrphanedSchedules bit = 0
)
as
begin
	set nocount, xact_abort on
	if @AllOrphanedSchedules = 1 throw 51000, 'Only current-database orphan schedule cleanup is supported; global cleanup cannot use the database operation lock.', 1;
	declare @c cursor, @Resource nvarchar(255) = z.fn_ResourceSQLScheduleOperation(), @ScheduleID int, @LockResult int,
		@Prefix nvarchar(300) = z.fn_GetScheduleNamePrefix();
	create table #ExistingSchedules
	(
		schedule_id int primary key, schedule_uid uniqueidentifier, schedule_name sysname, enabled int, 
		freq_type int, freq_interval int, freq_subday_type int, freq_subday_interval int, freq_relative_interval int,
		freq_recurrence_factor int, active_start_date int, active_end_date int, active_start_time int, active_end_time int,
		date_created datetime, schedule_description	nvarchar(4000), job_count int
		index schedule_name(schedule_name)
	)
	begin try
	begin tran
	exec @LockResult = sys.sp_getapplock @Resource = @Resource, @LockMode = N'Exclusive', @LockOwner = N'Transaction', @LockTimeout = 15000;
	if @LockResult < 0 throw 51001, 'Could not acquire the database schedule operation lock.', 1;
	insert into #ExistingSchedules(schedule_id, schedule_uid, schedule_name, enabled, freq_type, freq_interval, freq_subday_type, freq_subday_interval, freq_relative_interval, freq_recurrence_factor, active_start_date, active_end_date, active_start_time, active_end_time, date_created, schedule_description, job_count)
		exec msdb.dbo.sp_help_schedule -- do not directly access tables in MSDB, no access on AWS RDS.
	set @c = cursor local for
		select schedule_id
		from #ExistingSchedules
		where left(schedule_name collate Latin1_General_100_BIN2, len(@Prefix collate Latin1_General_100_BIN2 + N'#') - 1) = @Prefix collate Latin1_General_100_BIN2
			and job_count = 0;
	open @c
	fetch next from @c into @ScheduleID
	while @@fetch_status = 0
	begin
		exec msdb.dbo.sp_delete_schedule @schedule_id = @ScheduleID
		fetch next from @c into @ScheduleID
	end
	close @c
	deallocate @c
	commit
	end try
	begin catch
		if @@trancount > 0
			rollback;
		throw;
	end catch
end