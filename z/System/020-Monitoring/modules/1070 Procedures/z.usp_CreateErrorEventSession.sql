create or alter procedure z.usp_CreateErrorEventSession
as
begin
	set nocount, xact_abort on;
	declare @TranCount int = @@trancount;
	if not exists (select 1 from sys.server_event_sessions where name = N'SchemaZ Error Events')
	begin
		begin try
			exec(N'create event session [SchemaZ Error Events] on server
		add event sqlserver.error_reported
		(
			action(package0.collect_system_time, package0.event_sequence,
				sqlserver.client_app_name, sqlserver.client_hostname, sqlserver.context_info, sqlserver.database_name,
				sqlserver.server_instance_name, sqlserver.session_server_principal_name, sqlserver.sql_text)
			where (severity > 10)
		)
		add target package0.ring_buffer(set max_memory = 4096)
		with (max_memory = 4096 KB, event_retention_mode = allow_single_event_loss, max_dispatch_latency = 30 seconds,
			max_event_size = 0 KB, memory_partition_mode = none, track_causality = off, startup_state = on);');
		end try
		begin catch
			if xact_state() = -1 or @@trancount <> @TranCount throw;
			if not exists (select 1 from sys.server_event_sessions where name = N'SchemaZ Error Events') throw;
		end catch
	end
	if not exists (select 1 from sys.dm_xe_sessions where name = N'SchemaZ Error Events')
	begin
		begin try
			exec(N'alter event session [SchemaZ Error Events] on server state = start;');
		end try
		begin catch
			if xact_state() = -1 or @@trancount <> @TranCount throw;
			if not exists (select 1 from sys.dm_xe_sessions where name = N'SchemaZ Error Events') throw;
		end catch
	end
end
