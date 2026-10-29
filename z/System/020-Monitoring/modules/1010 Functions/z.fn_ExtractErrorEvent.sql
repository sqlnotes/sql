create or alter function z.fn_ExtractErrorEvent
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
			try_convert(int, nullif(d.value('(data[@name="error_number"]/value/text())[1]', 'nvarchar(100)'), N'')) ErrorNumber,
			try_convert(int, nullif(d.value('(data[@name="severity"]/value/text())[1]', 'nvarchar(100)'), N'')) Severity,
			try_convert(int, nullif(d.value('(data[@name="state"]/value/text())[1]', 'nvarchar(100)'), N'')) State,
			try_convert(bit, nullif(d.value('(data[@name="user_defined"]/value/text())[1]', 'nvarchar(100)'), N'')) IsUserDefined,
			try_convert(int, nullif(d.value('(data[@name="category"]/value/text())[1]', 'nvarchar(100)'), N'')) ErrorCategory,
			case when d.exist('data[@name="category"]/text') = 1 then d.value('(data[@name="category"]/text/text())[1]', 'nvarchar(100)') end ErrorCategoryText,
			try_convert(int, nullif(d.value('(data[@name="destination"]/value/text())[1]', 'nvarchar(100)'), N'')) ErrorDestination,
			case when d.exist('data[@name="destination"]/text') = 1 then d.value('(data[@name="destination"]/text/text())[1]', 'nvarchar(100)') end ErrorDestinationText,
			try_convert(bit, nullif(d.value('(data[@name="is_intercepted"]/value/text())[1]', 'nvarchar(100)'), N'')) IsIntercepted,
			case when d.exist('data[@name="message"]/value') = 1 then d.value('(data[@name="message"]/value/text())[1]', 'nvarchar(max)') end ErrorMessage,
			case when d.exist('action[@name="sql_text"]/value') = 1 then d.value('(action[@name="sql_text"]/value/text())[1]', 'nvarchar(max)') end SQLText,
			case when d.exist('action[@name="session_server_principal_name"]/value') = 1 then d.value('(action[@name="session_server_principal_name"]/value/text())[1]', 'nvarchar(128)') end SessionServerPrincipalName,
			case when d.exist('action[@name="server_instance_name"]/value') = 1 then d.value('(action[@name="server_instance_name"]/value/text())[1]', 'nvarchar(128)') end ServerInstanceName,
			case when d.exist('action[@name="database_name"]/value') = 1 then d.value('(action[@name="database_name"]/value/text())[1]', 'nvarchar(128)') end DatabaseName,
			case when d.exist('action[@name="context_info"]/value') = 1 then d.value('(action[@name="context_info"]/value/text())[1]', 'varchar(512)') end ContextInfo,
			case when d.exist('action[@name="client_hostname"]/value') = 1 then d.value('(action[@name="client_hostname"]/value/text())[1]', 'nvarchar(128)') end HostName,
			case when d.exist('action[@name="client_app_name"]/value') = 1 then d.value('(action[@name="client_app_name"]/value/text())[1]', 'nvarchar(128)') end ApplicationName,
			d.query('.') EventBody
		from @TargetData.nodes('RingBufferTarget/event') n(d)
		where d.value('@name', 'nvarchar(128)') in (N'error_reported')
	)
	select x.EventDateUTC, x.EventName, x.EventSequence,
		x.ErrorNumber, x.Severity, x.State, x.IsUserDefined, x.ErrorCategory, x.ErrorCategoryText, x.ErrorDestination, x.ErrorDestinationText, x.IsIntercepted, x.ErrorMessage, x.SQLText, x.SessionServerPrincipalName, x.ServerInstanceName, x.DatabaseName, x.ContextInfo, x.HostName, x.ApplicationName, x.EventBody
	from x
)
