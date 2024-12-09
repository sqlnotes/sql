create or alter view z.v_ActiveSessions
as
	select  r.Session_ID SessionID, r.start_time StartDate,r.blocking_session_id BlockingSessionID, datediff(second,r.start_time, getdate()) DurationInSecond, 
		r.status Status, r.command Command,
		r.wait_type WaitType, r.wait_time WaitTime, r.wait_resource WaitResource, r.last_wait_type LastWaitType,
		r.cpu_time CPU, r.reads Reads, r.writes Writes, r.logical_reads LogicalReads, r.total_elapsed_time TotalElapsedTime,
		db_name(r.database_id) DatabaseName,
		t.text SQLText, p.query_plan QueryPlan, 
		r.granted_query_memory GrantedMemory, r.nest_level NestedLevel, r.row_count [RowCount], r.open_transaction_count OpenTranCount, r.transaction_isolation_level TransactionIsolationLevel, 
		s.login_name LoginName, s.host_name HostName, c.client_net_address HostAddress,s.program_name ApplicationName
	from sys.dm_exec_requests r
		left outer join sys.dm_exec_sessions s on r.session_id = s.session_id
		left outer join sys.dm_exec_connections c on c.session_id = s.session_id
		outer apply sys.dm_exec_sql_text(r.sql_handle) t
		outer apply sys.dm_exec_query_plan(r.plan_handle) p
	where r.session_id not in (@@SPID)