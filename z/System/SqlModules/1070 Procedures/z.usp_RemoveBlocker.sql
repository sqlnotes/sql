create or alter procedure z.usp_RemoveBlocker
as
begin
	set nocount on
	if @@trancount > 0
	begin
		raiserror('z.usp_RemoveBlocker must not be executed within a transaction.', 16, 1)
		return;
	end
	if z.fn_IsSQLAgentRunning() = 0
	begin
		raiserror('SQL Agent is not running.', 16, 1)
		return
	end
	declare @SQL nvarchar(max), @Proc nvarchar(128)
	select @Proc = '##usp_RemoveBlocker_'+ cast(@@spid as nvarchar(20))
	select @SQL = cast('create or alter procedure ' + @Proc as nvarchar(max)) +'
as
begin
	set nocount on
	declare @StartDate datetime = null, @SQL nvarchar(max), @ContextInfo nvarchar(28) = ' + quotename(@Proc, '''') + ', @SessionID int = ' + cast(@@spid as nvarchar(max)) + ', @BlockingSessionID int
	while 1=1
	begin
		select @BlockingSessionID = (
										select top 1 r.blocking_session_id
										from sys.dm_exec_requests r
											inner join sys.dm_exec_sessions s on s.is_user_process = 1 and s.session_id = r.blocking_session_id
										where r.session_id = @SessionID
											and r.blocking_session_id <> @SessionID
									)
		if @BlockingSessionID is null --- no more active session, wait for 2 sec
		begin
			waitfor delay ''00:00:00.010''
			if @StartDate is null
			begin
				select @StartDate = getdate()
			end
			else if dateadd(second, 2, @StartDate) < getdate()
			begin
				if not exists(select * from sys.dm_exec_requests r where r.session_id = @SessionID) -- last check, if no active session, quit and cleanup.
					break;
			end
			continue;
		end
		else
		begin
			select @StartDate = null, @SQL = ''kill '' + cast(@BlockingSessionID as nvarchar(max))
			begin try
				exec(@SQL)
			end try
			begin catch
			end catch
		end
	end
	drop procedure ' + @Proc + ';
end'
	if z.fn_GetServiceJobID(@Proc) is null
	begin
		exec (@SQL)
		exec z.usp_CreateServiceJob @Name = @Proc, @ProcedureName = @Proc, @Description = @Proc, @DeleteAfterRun = 3, @Interval = 3600, @DailyAt = null, @CheckRegistry = 0	
		exec z.usp_StartServiceJob @Name = @Proc
	end
end