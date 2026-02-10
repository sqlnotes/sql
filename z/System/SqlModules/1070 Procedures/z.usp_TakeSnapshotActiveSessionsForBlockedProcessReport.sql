create or alter procedure z.usp_TakeSnapshotActiveSessionsForBlockedProcessReport
(
	@TraceSequence bigint,
	@TraceID int = null,
	@EventName nvarchar(128) = null

)
as
begin
	set nocount, xact_abort on
	set transaction isolation level read uncommitted
	
	declare @TransactionID bigint, @Date datetime = cast(getdate() as datetime2(0)), @TextData nvarchar(max),
			@SessionContext1 sql_variant, @SessionContext2 sql_variant
			
	select @TransactionID = TransactionID, @TextData = TextData
	from z.TraceBlockedProcessReport
	where TraceSequence = @TraceSequence 
	if @@rowcount = 0 or @TextData is null
		return;
	
	if	@TextData like '%MScdc%'
		or @TextData like '%vid_device_name%'
		or @TextData like '%VIRTUAL_DEVICE%'
		or @TextData like '%BACKUP%'
		or @TextData like '%QRTZ%'
		return

	select	@SessionContext1 = session_context(N'z.usp_TakeSnapshotActiveSessionsForBlockedProcessReport-1'),
			@SessionContext2 = session_context(N'z.usp_TakeSnapshotActiveSessionsForBlockedProcessReport-2')
	if @SessionContext1 is not null
	begin
		if cast(@SessionContext1 as bigint) = @TransactionID
			return
		if cast(@SessionContext2 as datetime) = @Date
			return
	end
	
	exec sp_set_session_context N'z.usp_TakeSnapshotActiveSessionsForBlockedProcessReport-1', @TransactionID
	exec sp_set_session_context N'z.usp_TakeSnapshotActiveSessionsForBlockedProcessReport-2', @Date
	

	insert into z.TraceBlockedProcessReportActiveSessions(TraceSequence, SessionID, StartDate, BlockingSessionID, DurationInSecond, Status, Command, WaitType, WaitTime, WaitResource, LastWaitType, CPU, Reads, Writes, LogicalReads, TotalElapsedTime, DatabaseName, SQLText, /*QueryPlan,*/ GrantedMemory, NestedLevel, [RowCount], OpenTranCount, TransactionIsolationLevel, LoginName, HostName, HostAddress, ApplicationName)
		select  @TraceSequence, SessionID, StartDate, BlockingSessionID, DurationInSecond, Status, Command, WaitType, WaitTime, WaitResource, LastWaitType, CPU, Reads, Writes, LogicalReads, TotalElapsedTime, DatabaseName, SQLText, /*QueryPlan,*/ GrantedMemory, NestedLevel, [RowCount], OpenTranCount, TransactionIsolationLevel, LoginName, HostName, HostAddress, ApplicationName
	from z.v_ActiveSessions
end
GO

