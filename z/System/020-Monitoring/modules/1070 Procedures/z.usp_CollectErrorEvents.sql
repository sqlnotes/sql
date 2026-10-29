create or alter procedure z.usp_CollectErrorEvents
as
begin
	set nocount, xact_abort on;
	set transaction isolation level read committed;
	declare @TargetData xml, @LockResult int;

	exec z.usp_CreateErrorEventSession;

	select @TargetData = cast(t.target_data as xml)
	from sys.dm_xe_sessions s
		inner join sys.dm_xe_session_targets t on t.event_session_address = s.address
	where s.name = N'SchemaZ Error Events' and t.target_name = N'ring_buffer';
	if @TargetData is null return;

	begin tran;
	begin try
		exec @LockResult = sys.sp_getapplock @Resource = N'z.usp_CollectErrorEvents', @LockMode = 'Exclusive', @LockOwner = 'Transaction', @LockTimeout = 10000;
		if @LockResult < 0 throw 51000, 'Unable to acquire the Extended Events collection lock.', 1;

		;with x as
		(
			select *, row_number() over(partition by EventDateUTC, EventName, EventSequence order by EventDateUTC) EventOrdinal
			from z.fn_ExtractErrorEvent(@TargetData)
		)
		insert into z.ErrorEvent(EventDateUTC, EventName, EventSequence, ErrorNumber, Severity, State, IsUserDefined, ErrorCategory, ErrorCategoryText, ErrorDestination, ErrorDestinationText, IsIntercepted, ErrorMessage, SQLText, SessionServerPrincipalName, ServerInstanceName, DatabaseName, ContextInfo, HostName, ApplicationName, EventBody)
			select x.EventDateUTC, x.EventName, x.EventSequence, x.ErrorNumber, x.Severity, x.State, x.IsUserDefined, x.ErrorCategory, x.ErrorCategoryText, x.ErrorDestination, x.ErrorDestinationText, x.IsIntercepted, x.ErrorMessage, x.SQLText, x.SessionServerPrincipalName, x.ServerInstanceName, x.DatabaseName, x.ContextInfo, x.HostName, x.ApplicationName, x.EventBody
			from x
			where x.EventOrdinal = 1 and not exists (
				select 1 from z.ErrorEvent e
				where e.EventDateUTC = x.EventDateUTC and e.EventName = x.EventName and e.EventSequence = x.EventSequence
			);
		commit;
	end try
	begin catch
		if @@trancount > 0 rollback;
		throw;
	end catch
end
