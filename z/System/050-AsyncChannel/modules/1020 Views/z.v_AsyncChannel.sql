/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/050-AsyncChannel/modules/1020%20Views/z.v_AsyncChannel.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/050-AsyncChannel/docs/reference/z.v_AsyncChannel.md

Resolved channel object names and validation reasons.
*/
create or alter view z.v_AsyncChannel
as
	select	r.AsyncChannelID, r.Name, r.Description, r.ProcessingProcedure, r.ActivationType,
			r.Readers, r.MaxRowsPerMessage, r.MaxMessagesPerReceive, r.MaxIdleDurationSeconds, r.MaxExecutionSeconds, r.IsActive, r.DebugMode, r.RowVersion,
			r.ActivatorPoolID, ActivatorPoolName = ap.Name, ActivatorPoolMaxConcurrency = ap.MaxConcurrency,
			r.SchemaName,
			r.SourceInterface, r.SourceInterfaceObjectID,
			r.SourceInterfaceTrigger, r.SourceInterfaceTriggerObjectID,
			r.ActivatorProcedure, r.ActivatorProcedureObjectID,
			r.ProcessingProcedureObjectID,
			r.EnqueueProcedure, r.EnqueueProcedureObjectID,
			r.Serializer, r.SerializerObjectID,
			r.Deserializer, r.DeserializerObjectID,
			r.QueueName, r.QueueObjectID,
			r.ServiceName, r.ServiceExists,
			IsValid = cast(iif(r.InvalidReason is null, 1, 0) as bit),
			r.InvalidReason
	from (
			select	g.*,
					InvalidReason = nullif(concat_ws('; ',
						iif(g.IsActive = 0, 'Channel is disabled (IsActive = 0)', null),
						iif(schema_id(g.SchemaName) is null, 'Schema ' + g.SchemaName + ' does not exist', null),
						iif(g.SourceInterfaceObjectID is null, 'SourceInterface ' + g.SourceInterface + ' does not exist', null),
						iif(g.SourceInterfaceTriggerObjectID is null, 'SourceInterfaceTrigger ' + g.SourceInterfaceTrigger + ' does not exist', null),
						iif(g.ActivatorProcedureObjectID is null, 'ActivatorProcedure ' + g.ActivatorProcedure + ' does not exist', null),
						iif(g.ProcessingProcedureObjectID is null, 'ProcessingProcedure ' + g.ProcessingProcedure + ' does not exist', null),
						iif(g.EnqueueProcedureObjectID is null, 'EnqueueProcedure ' + g.EnqueueProcedure + ' does not exist', null),
						iif(g.SerializerObjectID is null, 'Serializer ' + g.Serializer + ' does not exist', null),
						iif(g.DeserializerObjectID is null, 'Deserializer ' + g.Deserializer + ' does not exist', null),
						iif(g.QueueObjectID is null, 'Queue ' + g.QueueName + ' does not exist', null),
						iif(g.ServiceExists = 0, 'Service ' + g.ServiceName + ' does not exist', null),
						iif(g.SourceInterfaceObjectID is not null and exists (select 1 from sys.columns col where col.object_id = g.SourceInterfaceObjectID and col.name in ('ConversationHandle', 'Payload', 'Attempt')), 'Interface columns must not be named ConversationHandle, Payload or Attempt (reserved by the generated Enqueue procedure)', null),
						iif(g.SerializerObjectID is not null and g.SourceInterfaceObjectID is not null and isnull(g.SerializerParamSig, '') <> isnull(g.InterfaceSig, ''), 'Serializer parameters (name/position/type) must match the interface columns', null),
						iif(g.DeserializerObjectID is not null and g.SourceInterfaceObjectID is not null and isnull(g.DeserializerOutputSig, '') <> isnull(g.InterfaceSig, ''), 'Deserializer output columns (name/position/type) must match the interface columns', null),
						iif(g.SerializerObjectID is not null and isnull(g.SerializerOutputSig, '') <> 'Json', 'Serializer must return a single column named Json', null),
						iif(g.DeserializerObjectID is not null and isnull(g.DeserializerInputSig, '') <> 'nvarchar(max)', 'Deserializer must take a single nvarchar(max) parameter', null),
						iif(g.ActivatorProcedureObjectID is not null and g.ActivatorParamCount <> 0, 'ActivatorProcedure must have no parameters', null),
						iif(g.ProcessingProcedureObjectID is not null and (g.ProcessingParamCount <> 1 or isnull(g.ProcessingParamTypeID, -1) <> type_id('z.AsyncChannelMessage')), 'ProcessingProcedure must have a single z.AsyncChannelMessage parameter', null)
					), '')
			from (
					select	m.*,
							InterfaceSig = (select string_agg(cast(col.column_id as varchar(10)) + ':' + col.name + ':' + z.fn_AsyncChannelTypeDef(col.user_type_id, col.max_length, col.precision, col.scale), '|') within group (order by col.column_id)
											from sys.columns col where col.object_id = m.SourceInterfaceObjectID),
							SerializerParamSig = (select string_agg(cast(p.parameter_id as varchar(10)) + ':' + substring(p.name, 2, 128) + ':' + z.fn_AsyncChannelTypeDef(p.user_type_id, p.max_length, p.precision, p.scale), '|') within group (order by p.parameter_id)
											from sys.parameters p where p.object_id = m.SerializerObjectID and p.parameter_id > 0),
							DeserializerOutputSig = (select string_agg(cast(col.column_id as varchar(10)) + ':' + col.name + ':' + z.fn_AsyncChannelTypeDef(col.user_type_id, col.max_length, col.precision, col.scale), '|') within group (order by col.column_id)
											from sys.columns col where col.object_id = m.DeserializerObjectID),
							SerializerOutputSig = (select string_agg(col.name, '|') within group (order by col.column_id) from sys.columns col where col.object_id = m.SerializerObjectID),
							DeserializerInputSig = (select string_agg(z.fn_AsyncChannelTypeDef(p.user_type_id, p.max_length, p.precision, p.scale), '|') within group (order by p.parameter_id) from sys.parameters p where p.object_id = m.DeserializerObjectID and p.parameter_id > 0),
							ActivatorParamCount = (select count(*) from sys.parameters p where p.object_id = m.ActivatorProcedureObjectID and p.parameter_id > 0),
							ProcessingParamCount = (select count(*) from sys.parameters p where p.object_id = m.ProcessingProcedureObjectID and p.parameter_id > 0),
							ProcessingParamTypeID = (select p.user_type_id from sys.parameters p where p.object_id = m.ProcessingProcedureObjectID and p.parameter_id = 1)
					from (
							select	c.AsyncChannelID, c.Name, c.Description, c.ProcessingProcedure, c.ActivationType,
									c.Readers, c.MaxRowsPerMessage, c.MaxMessagesPerReceive, c.MaxIdleDurationSeconds, c.MaxExecutionSeconds, c.IsActive, c.DebugMode, c.RowVersion,
									c.ActivatorPoolID,
									c.SchemaName,
									c.SourceInterface, object_id(c.SourceInterface) SourceInterfaceObjectID,
									c.SourceInterfaceTrigger, object_id(c.SourceInterfaceTrigger) SourceInterfaceTriggerObjectID,
									c.ActivatorProcedure, object_id(c.ActivatorProcedure) ActivatorProcedureObjectID,
									object_id(c.ProcessingProcedure) ProcessingProcedureObjectID,
									c.EnqueueProcedure, object_id(c.EnqueueProcedure) EnqueueProcedureObjectID,
									c.Serializer, object_id(c.Serializer) SerializerObjectID,
									c.Deserializer, object_id(c.Deserializer) DeserializerObjectID,
									c.QueueName, object_id(c.QueueName) QueueObjectID,
									c.ServiceName, ServiceExists = iif(exists (select 1 from sys.services s where s.name collate database_default = c.ServiceName), 1, 0)
							from (
									select	c.AsyncChannelID, c.Name, c.Description, c.ProcessingProcedure, c.ActivationType,
											c.Readers, c.MaxRowsPerMessage, c.MaxMessagesPerReceive, c.MaxIdleDurationSeconds, c.MaxExecutionSeconds, c.IsActive, c.DebugMode, c.RowVersion,
											c.ActivatorPoolID,
											c.SchemaName,
											SourceInterface = c.SchemaName + '.AsyncChannel_' + c.Name + '_Interface',
											SourceInterfaceTrigger = c.SchemaName + '.TRI_AsyncChannel_' + c.Name + '_Interface',
											ActivatorProcedure = c.SchemaName + '.usp_AsyncChannel_' + c.Name + '_Activator',
											EnqueueProcedure = c.SchemaName + '.usp_AsyncChannel_' + c.Name + '_Enqueue',
											Serializer = c.SchemaName + '.fn_AsyncChannelSerializer_' + c.Name,
											Deserializer = c.SchemaName + '.fn_AsyncChannelDeserializer_' + c.Name,
											QueueName = c.SchemaName + '.AsyncChannelQueue_' + c.Name,
											ServiceName = '/SchemaZ/AsyncChannel/' + c.SchemaName + '/' + c.Name + '/Service'
									from (
											-- A channel's objects live in its ProcessingProcedure's schema ('z' when unqualified).
											select c.*, SchemaName = isnull(parsename(c.ProcessingProcedure, 2), 'z')
											from z.AsyncChannel c
										)c
								)c
						)m
				)g
		)r
		left join z.AsyncChannelActivatorPool ap on ap.ActivatorPoolID = r.ActivatorPoolID
