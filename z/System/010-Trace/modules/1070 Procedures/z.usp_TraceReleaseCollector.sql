create or alter procedure z.usp_TraceReleaseCollector
as
begin
	set nocount on;
	if @@trancount > 0
	begin
		set xact_abort off;
		throw 50000, N'Trace collector release requires no existing transaction.', 1;
	end;
	set xact_abort on;
	declare @CollectorUUID uniqueidentifier = try_convert(uniqueidentifier, session_context(N'Schema z.TraceCollector.UUID')), @LockResult int;
	begin try
		begin tran;
		exec @LockResult = sys.sp_getapplock @Resource = N'Schema z.TraceCollector', @LockMode = N'Exclusive', @LockOwner = N'Transaction', @LockTimeout = 5000;
		if @LockResult < 0 throw 50000, N'Trace collector admission or cleanup is already in progress.', 1;
		if not exists(select 1 from z.TraceCollectorTrace where CollectorUUID = @CollectorUUID)
			and not exists(select 1 from z.Trace where CollectorUUID = @CollectorUUID)
		begin
			delete z.TraceCollector where CollectorUUID = @CollectorUUID and OwnerSessionID = @@spid
				and OwnerLoginTime = (select login_time from sys.dm_exec_sessions where session_id = @@spid);
			if @@rowcount > 0 exec sys.sp_set_session_context @key = N'Schema z.TraceCollector.UUID', @value = null;
		end;
		commit;
	end try
	begin catch
		if @@trancount > 0 rollback;
		throw;
	end catch;
end;
go
