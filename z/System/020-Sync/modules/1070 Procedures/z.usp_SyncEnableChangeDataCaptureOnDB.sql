create or alter procedure z.usp_SyncEnableChangeDataCaptureOnDB
(
	@ServerName nvarchar(128) = null,
	@DatabaseName nvarchar(128) = null,
	@RetentionDays int = 15,
	@SQL nvarchar(max) = null output,
	@ExecuteSQL bit = 1
)
as
begin
	set nocount on
	set xact_abort off
	declare @RetentionMinutes int  = @RetentionDays * 1440
	select @DatabaseName = isnull(@DatabaseName,db_name())
	select @SQL = 'if not exists(select * from sys.databases where name = '+quotename(@DatabaseName , '''')+' and is_cdc_enabled = 1)
	begin
		if z.fn_IsAmazonRDS() = 1
		begin
			exec msdb.dbo.rds_cdc_enable_db '+quotename(@DatabaseName , '''')+'
		end
		else
		begin
			exec sys.sp_cdc_enable_db;
		end
	end
	if object_id(''dbo.sysarticles'') is not null
	begin
		if exists(select * from dbo.sysarticles)
		begin
			return;
		end;
	end
	begin try
	begin tran
	exec sp_getapplock @Resource = ''CheckCDCJob'', @LockMode = ''Exclusive'', @LockOwner = ''Transaction'', @LockTimeout = -1
	declare @MaxTrans int = 1000, @MaxScans int = 10000, @Continuous int = 1, @PullingInterval bigint = 1,
			@Retention bigint = ' + cast(@RetentionMinutes as varchar(20)) + ', @Threshold bigint = 1500

	create table #1(JobID uniqueidentifier, JobType nvarchar(20), JobName nvarchar(500), MaxTrans int, MaxScans int, Continuous int, PullingInterval bigint, Retention bigint, Threshold bigint)
	insert into #1
		exec sys.sp_cdc_help_jobs

	if not exists(select * from #1 where JobType = ''capture'')
	begin
		exec sys.sp_cdc_add_job @job_type = N''capture'', @start_job = 1, @continuous = @Continuous, @pollinginterval = @PullingInterval, @maxtrans = @MaxTrans, @maxscans = @MaxScans;
	end
	if not exists(select * from #1 where JobType = ''cleanup'')
	begin
		exec sys.sp_cdc_add_job @job_type=N''cleanup'', @retention=@Retention, @threshold = @Threshold
	end
	delete #1
	insert into #1
		exec sys.sp_cdc_help_jobs
	if not exists(select * from #1 where JobType = ''capture'' and (MaxTrans <> @MaxTrans or @MaxScans <> @MaxScans or Continuous <> @Continuous or @PullingInterval <> @PullingInterval))
	begin
		exec sys.sp_cdc_change_job @job_type = N''capture'', @continuous = @Continuous, @pollinginterval = @PullingInterval, @maxtrans = @MaxTrans, @maxscans = @MaxScans;
	end

	if exists(select * from #1 where JobType = ''cleanup'' and (Retention <> @Retention or Threshold <> @Threshold))
	begin
		exec sys.sp_cdc_change_job @job_type=N''cleanup'', @retention=@Retention, @threshold = @Threshold
	end
	commit
	end try
	begin catch
		if @@trancount > 0
			rollback;
		throw;
	end catch
	'
	if @ExecuteSQL = 1
	begin
		exec z.usp_SyncExecuteSQL @ServerName, @DatabaseName, @SQL
	end
end


go
