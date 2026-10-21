create or alter procedure z.usp_TraceRegisterCollector
(
	@CollectorUUID uniqueidentifier output
)
as
begin
	set nocount on;
	if @@trancount > 0
	begin
		set xact_abort off;
		throw 50000, N'Trace collector registration requires no existing transaction.', 1;
	end;
	set xact_abort on;
	exec z.usp_TraceCleanupCollectors;
	declare @LoginTime datetime = (select login_time from sys.dm_exec_sessions where session_id = @@spid), @LockResult int;
	begin try
		begin tran;
		exec @LockResult = sys.sp_getapplock @Resource = N'Schema z.TraceCollector', @LockMode = N'Exclusive', @LockOwner = N'Transaction', @LockTimeout = 5000;
		if @LockResult < 0 throw 50000, N'Trace collector admission or cleanup is already in progress.', 1;
		select @CollectorUUID = null;
		select @CollectorUUID = CollectorUUID from z.TraceCollector where OwnerSessionID = @@spid and OwnerLoginTime = @LoginTime;
		if @CollectorUUID is null
		begin
			select @CollectorUUID = newid();
			insert z.TraceCollector (CollectorUUID, OwnerSessionID, OwnerLoginTime) values (@CollectorUUID, @@spid, @LoginTime);
		end;
		-- Set before committing so a read-only/conflicting key cannot leave an admitted empty run.
		exec sys.sp_set_session_context @key = N'Schema z.TraceCollector.UUID', @value = @CollectorUUID;
		commit;
	end try
	begin catch
		if @@trancount > 0 rollback;
		throw;
	end catch;
end;
go
