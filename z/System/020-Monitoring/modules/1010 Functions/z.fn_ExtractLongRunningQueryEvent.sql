create or alter function z.fn_ExtractLongRunningQueryEvent
(
	@TargetData xml
)
returns table
as
return
(
	with x as
	(
		select convert(datetime, switchoffset(try_convert(datetimeoffset(7), d.value('@timestamp', 'nvarchar(50)'), 127), '+00:00')) EventDateUTC,
			d.value('@name', 'nvarchar(128)') EventName,
			try_convert(bigint, nullif(d.value('(action[@name="event_sequence"]/value/text())[1]', 'nvarchar(100)'), N'')) EventSequence,
			try_convert(int, nullif(d.value('(action[@name="session_id"]/value/text())[1]', 'nvarchar(100)'), N'')) SessionID,
			try_convert(bigint, nullif(d.value('(data[@name="cpu_time"]/value/text())[1]', 'nvarchar(100)'), N'')) CPU,
			cast(try_convert(bigint, nullif(d.value('(data[@name="duration"]/value/text())[1]', 'nvarchar(100)'), N'')) / 1000.0 as numeric(38,3)) DurationInMS,
			try_convert(bigint, nullif(d.value('(data[@name="physical_reads"]/value/text())[1]', 'nvarchar(100)'), N'')) PhysicalReads,
			try_convert(bigint, nullif(d.value('(data[@name="logical_reads"]/value/text())[1]', 'nvarchar(100)'), N'')) LogicalReads,
			try_convert(bigint, nullif(d.value('(data[@name="writes"]/value/text())[1]', 'nvarchar(100)'), N'')) Writes,
			try_convert(bigint, nullif(d.value('(data[@name="row_count"]/value/text())[1]', 'nvarchar(100)'), N'')) [RowCount],
			case when d.exist('data[@name="connection_reset_option"]/text') = 1 then d.value('(data[@name="connection_reset_option"]/text/text())[1]', 'nvarchar(50)') end ConnectionResetOption,
			case when d.exist('data[@name="object_name"]/value') = 1 then d.value('(data[@name="object_name"]/value/text())[1]', 'nvarchar(128)') end ObjectName,
			coalesce(nullif(d.value('(data[@name="statement"]/value/text())[1]', 'nvarchar(max)'), N''), nullif(d.value('(data[@name="batch_text"]/value/text())[1]', 'nvarchar(max)'), N''), nullif(d.value('(action[@name="sql_text"]/value/text())[1]', 'nvarchar(max)'), N'')) SQLText,
			case when d.exist('action[@name="server_principal_name"]/value') = 1 then d.value('(action[@name="server_principal_name"]/value/text())[1]', 'nvarchar(128)') end ServerPrincipalName,
			case when d.exist('action[@name="database_name"]/value') = 1 then d.value('(action[@name="database_name"]/value/text())[1]', 'nvarchar(128)') end DatabaseName,
			case when d.exist('action[@name="context_info"]/value') = 1 then d.value('(action[@name="context_info"]/value/text())[1]', 'varchar(512)') end ContextInfo,
			case when d.exist('action[@name="client_hostname"]/value') = 1 then d.value('(action[@name="client_hostname"]/value/text())[1]', 'nvarchar(128)') end HostName,
			case when d.exist('action[@name="client_app_name"]/value') = 1 then d.value('(action[@name="client_app_name"]/value/text())[1]', 'nvarchar(128)') end ApplicationName,
			d.query('.') EventBody
		from @TargetData.nodes('RingBufferTarget/event') n(d)
		where d.value('@name', 'nvarchar(128)') in (N'rpc_completed', N'sql_batch_completed', N'sp_statement_completed', N'sql_statement_completed')
	)
	select x.EventDateUTC, x.EventName, x.EventSequence,
		x.SessionID, x.CPU, x.DurationInMS, x.PhysicalReads, x.LogicalReads, x.Writes, x.[RowCount], x.ConnectionResetOption, x.ObjectName, x.SQLText, x.ServerPrincipalName, x.DatabaseName, x.ContextInfo, x.HostName, x.ApplicationName, x.EventBody
	from x
)
