create or alter procedure z.usp_CollectLongRunningQueryEvents
as
begin
	set nocount, xact_abort on;
	set transaction isolation level read committed;
	declare @TargetData xml, @LockResult int;

	exec z.usp_CreateLongRunningQueryEventSession;

	select @TargetData = cast(t.target_data as xml)
	from sys.dm_xe_sessions s
		inner join sys.dm_xe_session_targets t on t.event_session_address = s.address
	where s.name = N'SchemaZ Long Running Query Events' and t.target_name = N'ring_buffer';
	if @TargetData is null return;

	begin tran;
	begin try
		exec @LockResult = sys.sp_getapplock @Resource = N'z.usp_CollectLongRunningQueryEvents', @LockMode = 'Exclusive', @LockOwner = 'Transaction', @LockTimeout = 10000;
		if @LockResult < 0 throw 51000, 'Unable to acquire the Extended Events collection lock.', 1;

		;with x as
		(
			select *, row_number() over(partition by EventDateUTC, EventName, EventSequence order by EventDateUTC) EventOrdinal
			from z.fn_ExtractLongRunningQueryEvent(@TargetData)
		)
		insert into z.LongRunningQueryEvent(EventDateUTC, EventName, EventSequence, SessionID, CPU, DurationInMS, PhysicalReads, LogicalReads, Writes, [RowCount], ConnectionResetOption, ObjectName, SQLText, ServerPrincipalName, DatabaseName, ContextInfo, HostName, ApplicationName, EventBody)
			select x.EventDateUTC, x.EventName, x.EventSequence, x.SessionID, x.CPU, x.DurationInMS, x.PhysicalReads, x.LogicalReads, x.Writes, x.[RowCount], x.ConnectionResetOption, x.ObjectName, x.SQLText, x.ServerPrincipalName, x.DatabaseName, x.ContextInfo, x.HostName, x.ApplicationName, x.EventBody
			from x
			where x.EventOrdinal = 1 and not exists (
				select 1 from z.LongRunningQueryEvent e
				where e.EventDateUTC = x.EventDateUTC and e.EventName = x.EventName and e.EventSequence = x.EventSequence
			);
		commit;
	end try
	begin catch
		if @@trancount > 0 rollback;
		throw;
	end catch
end
