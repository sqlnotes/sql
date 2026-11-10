/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/050-AsyncChannel/modules/1030%20Script%20Views/z.v_AsyncChannelScripts.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/050-AsyncChannel/docs/reference/z.v_AsyncChannelScripts.md

Generated scripts, existing definitions and deployment/drift flags.
*/
create or alter view z.v_AsyncChannelScripts
as
	select
		v.AsyncChannelID, v.Name, s.Ordinal, s.ObjectType, s.ObjectName, s.GeneratedScript,
		e.ExistingScript,
		-- The engine stores 'create or alter <type>' as 'create   <type>', so compare both forms.
		IsSameScript = cast(iif(e.ExistingScript is null, null,
				iif(e.ExistingScript = s.GeneratedScript or e.ExistingScript = stuff(s.GeneratedScript, 1, 16, N'create   '), 1, 0)) as bit),
		NeedDeployment = cast(case
				when s.ObjectType = 'Service' then iif(exists (select 1 from sys.services where name collate database_default = s.ObjectName), 0, 1)
				when s.ObjectType = 'ActivatorBinding' then
					case when v.ActivationType = 'Auto'
						then iif(exists (select 1 from sys.service_queues q where q.object_id = object_id(v.QueueName) and q.is_activation_enabled = 1 and object_id(q.activation_procedure) = object_id(v.ActivatorProcedure) and q.max_readers = v.Readers), 0, 1)
						else iif(exists (select 1 from sys.service_queues q where q.object_id = object_id(v.QueueName) and q.is_activation_enabled = 1), 1, 0)
					end
				else iif(object_id(s.ObjectName) is null, 1, 0)
			end as bit)
	from z.v_AsyncChannel v
		cross apply (select nl = cast(nchar(13) + nchar(10) as nvarchar(max)),
					t1 = nchar(9), t2 = replicate(nchar(9), 2), t3 = replicate(nchar(9), 3),
					t4 = replicate(nchar(9), 4), t5 = replicate(nchar(9), 5), t6 = replicate(nchar(9), 6)) f
		outer apply (
			select
				ParamList         = string_agg(cast(c.ParamDecl as nvarchar(max)), N',
		') within group (order by c.column_id),
				ParamListNull     = string_agg(cast(c.ParamDecl + N' = null' as nvarchar(max)), N',
		') within group (order by c.column_id),
				SerializeList     = string_agg(cast(c.SerializeExpr as nvarchar(max)), N',
				') within group (order by c.column_id),
				OpenJsonWithList  = string_agg(cast(c.OpenJsonWith as nvarchar(max)), N',
			') within group (order by c.column_id),
				OuterSelectList   = string_agg(cast(c.OuterSelect as nvarchar(max)), N',
			') within group (order by c.column_id),
				ValueArgList      = string_agg(cast(N'@' + c.ColumnName as nvarchar(max)), N', ') within group (order by c.column_id),
				CrossApplyArgList = string_agg(cast(c.CrossApplyArg as nvarchar(max)), N', ') within group (order by c.column_id),
				InterfaceColumnList = string_agg(cast(c.ColumnName + N' = cast(null as ' + c.TypeName + N')' as nvarchar(max)), N',
		') within group (order by c.column_id)
			from z.fn_AsyncChannelColumns(v.SourceInterfaceObjectID) c
		) a
		cross apply (values
			(1, N'Interface', v.SourceInterface,
				N'create or alter view ' + v.SourceInterface + f.nl + N'as' + f.nl +
				f.t1 + N'select top 0' + f.nl +
				f.t2 + isnull(a.InterfaceColumnList, N'cast(null as int) C0')
			),
			(5, N'Queue', v.QueueName,
				N'create queue ' + v.QueueName + N' with status = on, retention = off, poison_message_handling (status = off);'
			),
			(6, N'Service', v.ServiceName,
				N'create service ' + quotename(v.ServiceName) + N' on queue ' + v.QueueName + N' ([/SchemaZ/AsyncChannel/Contract]);'
			),
			(20, N'Serializer', v.Serializer,
				N'create or alter function ' + v.Serializer + f.nl +
				N'(' + f.nl +
				f.t2 + a.ParamList + f.nl +
				N')' + f.nl +
				N'returns table' + f.nl +
				N'as return' + f.nl +
				f.t1 + N'select Json =' + f.nl +
				f.t1 + N'(' + f.nl +
				f.t2 + N'select' + f.nl +
				f.t4 + a.SerializeList + f.nl +
				f.t2 + N'for json path, without_array_wrapper' + f.nl +
				f.t1 + N');'
			),
			(30, N'Deserializer', v.Deserializer,
				N'create or alter function ' + v.Deserializer + N'(@Data nvarchar(max))' + f.nl +
				N'returns table' + f.nl +
				N'as return' + f.nl +
				f.t1 + N'select' + f.nl +
				f.t3 + a.OuterSelectList + f.nl +
				f.t1 + N'from openjson(N''['' + @Data + N'']'') with' + f.nl +
				f.t1 + N'(' + f.nl +
				f.t3 + a.OpenJsonWithList + f.nl +
				f.t1 + N') o;'
			),
			(40, N'Trigger', v.SourceInterfaceTrigger,
				N'create or alter trigger ' + v.SourceInterfaceTrigger + N' on ' + v.SourceInterface + f.nl +
				N'instead of insert' + f.nl +
				N'as' + f.nl +
				N'begin' + f.nl +
				f.t1 + N'set nocount on;' + f.nl +
				f.t1 + N'if not exists (select 1 from inserted)' + f.nl +
				f.t2 + N'return;' + f.nl + f.nl +
				f.t1 + N'declare @Handle uniqueidentifier, @MaxRows int, @Payload nvarchar(max), @Attempt int;' + f.nl +
				f.t1 + N'exec z.usp_AsyncChannelGetConversationHandle @AsyncChannelID = ' + cast(v.AsyncChannelID as nvarchar(10)) + N', @ConversationHandle = @Handle output, @MaxRowsPerMessage = @MaxRows output;' + f.nl +
				f.t1 + N'if @Handle is null' + f.nl +
				f.t2 + N'return;' + f.nl + f.nl +
				f.t1 + N'declare Chunks cursor local static for' + f.nl +
				f.t2 + N'select string_agg(c.Json, N'','')' + f.nl +
				f.t2 + N'from (' + f.nl +
				f.t4 + N'select' + f.nl +
				f.t5 + N'ChunkID = iif(@MaxRows is null, 0, (cast(row_number() over (order by (select 1)) as int) - 1) / @MaxRows),' + f.nl +
				f.t5 + N's.Json' + f.nl +
				f.t4 + N'from inserted i' + f.nl +
				f.t5 + N'cross apply ' + v.Serializer + N'(' + a.CrossApplyArgList + N') s' + f.nl +
				f.t3 + N') c' + f.nl +
				f.t2 + N'group by c.ChunkID' + f.nl +
				f.t2 + N'order by c.ChunkID;' + f.nl +
				f.t1 + N'open Chunks;' + f.nl +
				f.t1 + N'fetch next from Chunks into @Payload;' + f.nl +
				f.t1 + N'while @@fetch_status = 0' + f.nl +
				f.t1 + N'begin' + f.nl +
				f.t2 + N'set @Attempt = 0;' + f.nl +
				f.t2 + N'while @Attempt < 2' + f.nl +
				f.t2 + N'begin' + f.nl +
				f.t3 + N'begin try' + f.nl +
				f.t4 + N';send on conversation @Handle message type [/SchemaZ/AsyncChannel/Message] (@Payload);' + f.nl +
				f.t4 + N'break;' + f.nl +
				f.t3 + N'end try' + f.nl +
				f.t3 + N'begin catch' + f.nl +
				f.t4 + N'if error_number() = 8426 and @Attempt = 0' + f.nl +
				f.t4 + N'begin' + f.nl +
				f.t5 + N'delete from z.AsyncChannelSession where AsyncChannelID = ' + cast(v.AsyncChannelID as nvarchar(10)) + N' and SessionID = @@spid;' + f.nl +
				f.t5 + N'exec z.usp_AsyncChannelGetConversationHandle @AsyncChannelID = ' + cast(v.AsyncChannelID as nvarchar(10)) + N', @ConversationHandle = @Handle output, @MaxRowsPerMessage = @MaxRows output;' + f.nl +
				f.t5 + N'if @Handle is null' + f.nl +
				f.t6 + N'return;' + f.nl +
				f.t5 + N'set @Attempt = @Attempt + 1;' + f.nl +
				f.t4 + N'end' + f.nl +
				f.t4 + N'else' + f.nl +
				f.t5 + N'throw;' + f.nl +
				f.t3 + N'end catch' + f.nl +
				f.t2 + N'end' + f.nl +
				f.t2 + N'fetch next from Chunks into @Payload;' + f.nl +
				f.t1 + N'end' + f.nl +
				f.t1 + N'close Chunks;' + f.nl +
				f.t1 + N'deallocate Chunks;' + f.nl +
				N'end'
			),
			(50, N'Enqueue', v.EnqueueProcedure,
				N'create or alter procedure ' + v.EnqueueProcedure + f.nl +
				N'(' + f.nl +
				f.t2 + a.ParamListNull + N',' + f.nl +
				f.t2 + N'@ConversationHandle uniqueidentifier = null' + f.nl +
				N')' + f.nl +
				N'as' + f.nl +
				N'begin' + f.nl +
				f.t1 + N'set nocount on;' + f.nl +
				f.t1 + N'declare @Payload nvarchar(max), @Attempt int = 0;' + f.nl + f.nl +
				f.t1 + N'if @ConversationHandle is null' + f.nl +
				f.t2 + N'exec z.usp_AsyncChannelGetConversationHandle @AsyncChannelID = ' + cast(v.AsyncChannelID as nvarchar(10)) + N', @ConversationHandle = @ConversationHandle output;' + f.nl +
				f.t1 + N'if @ConversationHandle is null' + f.nl +
				f.t2 + N'return;' + f.nl + f.nl +
				f.t1 + N'select @Payload = Json' + f.nl +
				f.t1 + N'from ' + v.Serializer + N'(' + a.ValueArgList + N');' + f.nl + f.nl +
				f.t1 + N'while @Attempt < 2' + f.nl +
				f.t1 + N'begin' + f.nl +
				f.t2 + N'begin try' + f.nl +
				f.t3 + N';send on conversation @ConversationHandle message type [/SchemaZ/AsyncChannel/Message] (@Payload);' + f.nl +
				f.t3 + N'break;' + f.nl +
				f.t2 + N'end try' + f.nl +
				f.t2 + N'begin catch' + f.nl +
				f.t3 + N'if error_number() = 8426 and @Attempt = 0' + f.nl +
				f.t3 + N'begin' + f.nl +
				f.t4 + N'delete from z.AsyncChannelSession where AsyncChannelID = ' + cast(v.AsyncChannelID as nvarchar(10)) + N' and SessionID = @@spid;' + f.nl +
				f.t4 + N'exec z.usp_AsyncChannelGetConversationHandle @AsyncChannelID = ' + cast(v.AsyncChannelID as nvarchar(10)) + N', @ConversationHandle = @ConversationHandle output;' + f.nl +
				f.t4 + N'if @ConversationHandle is null' + f.nl +
				f.t5 + N'return;' + f.nl +
				f.t4 + N'set @Attempt = @Attempt + 1;' + f.nl +
				f.t3 + N'end' + f.nl +
				f.t3 + N'else' + f.nl +
				f.t4 + N'throw;' + f.nl +
				f.t2 + N'end catch' + f.nl +
				f.t1 + N'end' + f.nl +
				N'end'
			),
			(70, N'Processing', v.ProcessingProcedure,
				N'create or alter procedure ' + v.ProcessingProcedure + f.nl +
				N'(' + f.nl +
				f.t2 + N'@Messages z.AsyncChannelMessage readonly' + f.nl +
				N')' + f.nl +
				N'as' + f.nl +
				N'begin' + f.nl +
				f.t1 + N'set nocount on;' + f.nl +
				-- Demo body: created only when the Processing procedure is missing, never overwritten (usp_AsyncChannelDeploy
				-- skips Processing, also with @ForceDeployment = 1). Every example is live code that is off until a variable is set.
				f.t1 + N'-- Generated starting point for channel ' + cast(v.AsyncChannelID as nvarchar(10)) + N' ' + v.Name + N': replace the body with the real processing.' + f.nl +
				f.t1 + N'-- The framework creates this procedure only when it is missing and never overwrites it (also not with @ForceDeployment = 1).' + f.nl +
				f.t1 + N'-- @Messages is one received batch, run inside the activator''s transaction: an error here rolls the receive back and the' + f.nl +
				f.t1 + N'-- batch is retried, so keep the processing idempotent. IsPayload = 1 rows carry the JSON of the interface rows; IsPayload = 0' + f.nl +
				f.t1 + N'-- rows are system messages the activator already handled (EndDialog, Error) or a DialogTimer (see 3).' + f.nl +
				f.t1 + N'declare @ForwardTo varchar(max) = null, @TimerSeconds int = null, @TimerTypeID int = cast(session_context(N''AsyncChannel-TimerTypeID'') as int), @Handle uniqueidentifier;' + f.nl + f.nl +
				f.t1 + N'-- 1. Deserialize: ' + v.Deserializer + N' turns one payload back into the interface columns of ' + v.SourceInterface + N'.' + f.nl +
				f.t1 + N'--    One message holds up to MaxRowsPerMessage rows. Insert or merge from this set instead of returning it.' + f.nl +
				f.t1 + N'select d.* from @Messages m cross apply ' + v.Deserializer + N'(m.Payload) d where m.IsPayload = 1;' + f.nl + f.nl +
				f.t1 + N'-- 2. Forward: hand the payload rows unchanged to other channels that share these interface columns. Set @ForwardTo to' + f.nl +
				f.t1 + N'--    their comma separated AsyncChannelIDs, e.g. N''10100, 10200''; unknown ids are logged and skipped. @Batched = 0 sends' + f.nl +
				f.t1 + N'--    one message per row instead of one per batch.' + f.nl +
				f.t1 + N'if @ForwardTo is not null' + f.nl +
				f.t1 + N'begin' + f.nl +
				f.t2 + N'exec z.usp_AsyncChannelForward @Messages = @Messages, @AsyncChannelIDs = @ForwardTo;' + f.nl +
				f.t1 + N'end' + f.nl + f.nl +
				f.t1 + N'-- 3. Timer: wake this channel up later. z.usp_AsyncChannelSetTimer arms a Service Broker conversation timer on one' + f.nl +
				f.t1 + N'--    conversation of the batch; after @TimerSeconds a DialogTimer message (IsPayload = 0, MessageTypeID = @TimerTypeID,' + f.nl +
				f.t1 + N'--    Payload null) arrives on this queue and reaches this procedure, alone or together with new payload rows. One pending' + f.nl +
				f.t1 + N'--    timer per conversation: arming again replaces it, ending the conversation removes it, there is no cancel.' + f.nl +
				f.t1 + N'if exists (select 1 from @Messages where MessageTypeID = @TimerTypeID)' + f.nl +
				f.t1 + N'begin' + f.nl +
				f.t2 + N'-- the delayed work goes here' + f.nl +
				f.t2 + N'exec z.usp_AsyncChannelLog @AsyncChannelID = ' + cast(v.AsyncChannelID as nvarchar(10)) + N', @Level = ''Info'', @Info = N''timer fired'', @SessionID = @@spid;' + f.nl +
				f.t1 + N'end' + f.nl +
				f.t1 + N'--    Arm on a conversation of this batch. z.fn_AsyncChannelCurrentTimer(@Handle) returns the seconds left of the pending' + f.nl +
				f.t1 + N'--    timer, null when there is none: arm only when nothing is pending, so a burst of batches does not keep pushing the' + f.nl +
				f.t1 + N'--    wake-up further out. Drop that check to restart the countdown with every batch instead.' + f.nl +
				f.t1 + N'select top (1) @Handle = ConversationHandle from @Messages where IsPayload = 1;' + f.nl +
				f.t1 + N'if @TimerSeconds is not null and @Handle is not null and z.fn_AsyncChannelCurrentTimer(@Handle) is null' + f.nl +
				f.t1 + N'begin' + f.nl +
				f.t2 + N'exec z.usp_AsyncChannelSetTimer @ConversationHandle = @Handle, @TimeoutSeconds = @TimerSeconds;' + f.nl +
				f.t1 + N'end' + f.nl +
				N'end'
			),
			(80, N'Activator', v.ActivatorProcedure,
				N'create or alter procedure ' + v.ActivatorProcedure + f.nl +
				N'as' + f.nl +
				N'begin' + f.nl +
				f.t1 + N'set nocount on;' + f.nl +
				-- Channel activators win deadlocks; interrupted peers (pollers, ad-hoc work) can retry,
				-- while a rolled-back receive would poison-retry and risk losing the batch.
				f.t1 + N'set deadlock_priority high;' + f.nl + f.nl +
				f.t1 + N'declare @AsyncChannelID int = ' + cast(v.AsyncChannelID as nvarchar(10)) + N', @MaxIdle int, @MaxExecution int, @MaxMessages int, @DebugMode bit, @Level varchar(20), @Info nvarchar(100), @ErrMsg nvarchar(4000), @Payload nvarchar(max), @Handle uniqueidentifier, @MsgTypeID int, @LastActivity datetime2(3) = sysutcdatetime(), @Started datetime2(3) = sysutcdatetime(), @ActivatorPoolID int, @PoolResult int, @ReceiveTimeout int;' + f.nl +
				f.t1 + N'select @MaxIdle = MaxIdleDurationSeconds, @MaxExecution = MaxExecutionSeconds, @MaxMessages = MaxMessagesPerReceive, @DebugMode = DebugMode from z.AsyncChannel where AsyncChannelID = @AsyncChannelID;' + f.nl + f.t1 + N'select @ReceiveTimeout = iif(@MaxIdle = 0, 0, 500);' + f.nl +
				f.t1 + N'exec sys.sp_set_session_context @key = N''AsyncChannel-AsyncChannelID'', @value = @AsyncChannelID;' + f.nl +
				f.t1 + N'exec sys.sp_set_session_context @key = N''AsyncChannel-DebugMode'', @value = @DebugMode;' + f.nl +
				f.t1 + N'exec sys.sp_set_session_context @key = N''AsyncChannel-MaxIdleDurationSeconds'', @value = @MaxIdle;' + f.nl +
				f.nl +
				-- Message type IDs never change once created; cache them in session context so a long-lived
				-- session (Manual pull, MaxIdle reader) reads sys.service_message_types once.
				f.t1 + N'declare @DataTypeID int = cast(session_context(N''AsyncChannel-DataTypeID'') as int), @EndDialogTypeID int = cast(session_context(N''AsyncChannel-EndDialogTypeID'') as int), @ErrorTypeID int = cast(session_context(N''AsyncChannel-ErrorTypeID'') as int), @TimerTypeID int = cast(session_context(N''AsyncChannel-TimerTypeID'') as int);' + f.nl +
				f.t1 + N'if @DataTypeID is null or @EndDialogTypeID is null or @ErrorTypeID is null or @TimerTypeID is null' + f.nl +
				f.t1 + N'begin' + f.nl +
				f.t2 + N'select	@DataTypeID = iif(name = N''/SchemaZ/AsyncChannel/Message'', message_type_id, @DataTypeID),' + f.nl +
				f.t4 + N'@EndDialogTypeID = iif(name = N''http://schemas.microsoft.com/SQL/ServiceBroker/EndDialog'', message_type_id, @EndDialogTypeID),' + f.nl +
				f.t4 + N'@ErrorTypeID = iif(name = N''http://schemas.microsoft.com/SQL/ServiceBroker/Error'', message_type_id, @ErrorTypeID),' + f.nl +
				f.t4 + N'@TimerTypeID = iif(name = N''http://schemas.microsoft.com/SQL/ServiceBroker/DialogTimer'', message_type_id, @TimerTypeID)' + f.nl +
				f.t2 + N'from sys.service_message_types' + f.nl +
				f.t2 + N'where name in (N''/SchemaZ/AsyncChannel/Message'', N''http://schemas.microsoft.com/SQL/ServiceBroker/EndDialog'', N''http://schemas.microsoft.com/SQL/ServiceBroker/Error'', N''http://schemas.microsoft.com/SQL/ServiceBroker/DialogTimer'');' + f.nl +
				f.t2 + N'exec sys.sp_set_session_context @key = N''AsyncChannel-DataTypeID'', @value = @DataTypeID;' + f.nl +
				f.t2 + N'exec sys.sp_set_session_context @key = N''AsyncChannel-EndDialogTypeID'', @value = @EndDialogTypeID;' + f.nl +
				f.t2 + N'exec sys.sp_set_session_context @key = N''AsyncChannel-ErrorTypeID'', @value = @ErrorTypeID;' + f.nl +
				f.t2 + N'exec sys.sp_set_session_context @key = N''AsyncChannel-TimerTypeID'', @value = @TimerTypeID;' + f.nl +
				f.t1 + N'end' + f.nl + f.nl +
				f.t1 + N'declare @Msgs z.AsyncChannelMessage;' + f.nl + f.nl +
				f.t1 + N'while (1 = 1)' + f.nl +
				f.t1 + N'begin' + f.nl +
				f.t2 + N'delete @Msgs;' + f.nl +
				f.t2 + N'exec z.usp_AsyncChannelLogFlush;' + f.nl +
				f.t2 + N'begin try' + f.nl +
				f.t3 + N'begin tran;' + f.nl +
				f.t3 + N'waitfor' + f.nl +
				f.t3 + N'(' + f.nl +
				f.t4 + N'receive top(@MaxMessages) conversation_handle, message_type_id, message_sequence_number, iif(message_type_id = @DataTypeID, 1, 0), cast(message_body as nvarchar(max))' + f.nl +
				f.t4 + N'from ' + v.QueueName + f.nl +
				f.t4 + N'into @Msgs' + f.nl +
				f.t3 + N'), timeout @ReceiveTimeout;' + f.nl +
				f.t3 + N'if not exists (select 1 from @Msgs)' + f.nl +
				f.t3 + N'begin' + f.nl +
				f.t4 + N'commit;' + f.nl +
				f.t4 + N'if @MaxIdle = 0 or datediff(second, @LastActivity, sysutcdatetime()) >= @MaxIdle or (@MaxExecution > 0 and datediff_big(millisecond, @Started, sysutcdatetime()) >= convert(bigint, @MaxExecution) * 1000)' + f.nl +
				f.t5 + N'break;' + f.nl +
				f.t3 + N'end' + f.nl +
				f.t3 + N'else' + f.nl +
				f.t3 + N'begin' + f.nl +
				f.t4 + N'set @LastActivity = sysutcdatetime();' + f.nl +
				f.t4 + N'declare c cursor local fast_forward for' + f.nl +
				-- DialogTimer rows are consumed by the receive and nothing else: not logged, not ended, no catalog lookup.
				f.t5 + N'select ConversationHandle, MessageTypeID, Payload from @Msgs where IsPayload = 0 and MessageTypeID <> @TimerTypeID;' + f.nl +
				f.t4 + N'open c;' + f.nl +
				f.t4 + N'fetch next from c into @Handle, @MsgTypeID, @Payload;' + f.nl +
				f.t4 + N'while @@fetch_status = 0' + f.nl +
				f.t4 + N'begin' + f.nl +
				f.t5 + N'select @Level = iif(@MsgTypeID = @ErrorTypeID, ''Error'', ''Info''), @Info = case @MsgTypeID when @EndDialogTypeID then N''EndDialog'' when @ErrorTypeID then N''Error'' else N''Unknown message type '' + cast(@MsgTypeID as nvarchar(10)) end;' + f.nl +
				f.t5 + N'exec z.usp_AsyncChannelLog @AsyncChannelID = @AsyncChannelID, @Level = @Level, @Info = @Info, @Payload = @Payload, @SessionID = @@spid, @ConversationHandle = @Handle;' + f.nl +
				f.t5 + N'if @MsgTypeID in (@EndDialogTypeID, @ErrorTypeID)' + f.nl +
				f.t6 + N'end conversation @Handle;' + f.nl +
				f.t5 + N'fetch next from c into @Handle, @MsgTypeID, @Payload;' + f.nl +
				f.t4 + N'end' + f.nl +
				f.t4 + N'close c;' + f.nl +
				f.t4 + N'deallocate c;' + f.nl + f.nl +
				-- Processing runs for payload rows and for DialogTimer rows (a timer is a wake-up for the Processing procedure).
				f.t4 + N'if exists (select 1 from @Msgs where IsPayload = 1 or MessageTypeID = @TimerTypeID)' + f.nl +
				f.t4 + N'begin' + f.nl +
				f.t5 + N'exec @PoolResult = z.usp_AsyncChannelActivatorPoolAcquire @AsyncChannelID = @AsyncChannelID, @ActivatorPoolID = @ActivatorPoolID output;' + f.nl +
				f.t5 + N'if @PoolResult < 0' + f.nl +
				f.t5 + N'begin' + f.nl +
				f.t6 + N'rollback;' + f.nl +
				f.t6 + N'exec z.usp_AsyncChannelLogFlush;' + f.nl +
				f.t6 + N'break;' + f.nl +
				f.t5 + N'end' + f.nl +
				f.t5 + N'exec ' + v.ProcessingProcedure + N' @Msgs;' + f.nl +
				f.t5 + N'if @DebugMode = 1' + f.nl +
				f.t5 + N'begin' + f.nl +
				f.t6 + N'select @ErrMsg = N''Processed '' + cast(sum(iif(IsPayload = 1, 1, 0)) as nvarchar(10)) + N'' payload and '' + cast(sum(iif(MessageTypeID = @TimerTypeID, 1, 0)) as nvarchar(10)) + N'' timer messages'', @Payload = string_agg(iif(IsPayload = 1, Payload, null), nchar(10)) from @Msgs;' + f.nl +
				f.t6 + N'exec z.usp_AsyncChannelLog @AsyncChannelID = @AsyncChannelID, @Level = ''Debug'', @Info = @ErrMsg, @Payload = @Payload, @SessionID = @@spid;' + f.nl +
				f.t5 + N'end' + f.nl +
				f.t4 + N'end' + f.nl +
				f.t4 + N'commit;' + f.nl +
				f.t4 + N'exec z.usp_AsyncChannelActivatorPoolRelease @ActivatorPoolID = @ActivatorPoolID;' + f.nl +
				f.t4 + N'select @ActivatorPoolID = null;' + f.nl +
				-- MaxExecutionSeconds bounds one call: a Manual pull under the ETL's transaction and an activated reader both return after it.
				f.t4 + N'if @MaxExecution > 0 and datediff_big(millisecond, @Started, sysutcdatetime()) >= convert(bigint, @MaxExecution) * 1000' + f.nl +
				f.t5 + N'break;' + f.nl +
				f.t3 + N'end' + f.nl +
				f.t2 + N'end try' + f.nl +
				f.t2 + N'begin catch' + f.nl +
				f.t3 + N'if @@trancount > 0' + f.nl +
				f.t4 + N'rollback;' + f.nl +
				f.t3 + N'exec z.usp_AsyncChannelActivatorPoolRelease @ActivatorPoolID = @ActivatorPoolID;' + f.nl +
				f.t3 + N'set @ErrMsg = z.fn_GetFullErrorMessage();' + f.nl +
				f.t3 + N'set @Payload = (select string_agg(Payload, nchar(10)) from @Msgs where IsPayload = 1);' + f.nl +
				f.t3 + N'begin try' + f.nl +
				-- outside the transaction now: the Error log drains the buffered rows itself before inserting
				f.t4 + N'exec z.usp_AsyncChannelLog @AsyncChannelID = @AsyncChannelID, @Level = ''Error'', @Info = @ErrMsg, @Payload = @Payload;' + f.nl +
				f.t3 + N'end try' + f.nl +
				f.t3 + N'begin catch' + f.nl +
				f.t3 + N'end catch' + f.nl +
				-- bound the poison-batch retry rate: the rollback put the batch back and Broker re-activates at once, so wait before leaving
				f.t3 + N'waitfor delay ''00:00:05'';' + f.nl +
				f.t3 + N'break;' + f.nl +
				f.t2 + N'end catch' + f.nl +
				f.t1 + N'end' + f.nl +
				f.t1 + N'exec z.usp_AsyncChannelLogFlush;' + f.nl +
				N'end'
			),
			(90, N'ActivatorBinding', v.QueueName,
				case when v.ActivationType = 'Auto'
					then N'if not exists (select 1 from sys.service_queues where object_id = object_id(''' + v.QueueName + N''') and is_activation_enabled = 1 and object_id(activation_procedure) = object_id(''' + v.ActivatorProcedure + N''') and max_readers = ' + cast(v.Readers as nvarchar(10)) + N')' + f.nl +
						f.t1 + N'alter queue ' + v.QueueName + N' with activation (status = on, procedure_name = ' + v.ActivatorProcedure + N', max_queue_readers = ' + cast(v.Readers as nvarchar(10)) + N', execute as owner);'
					else N'if exists (select 1 from sys.service_queues where object_id = object_id(''' + v.QueueName + N''') and is_activation_enabled = 1)' + f.nl +
						f.t1 + N'alter queue ' + v.QueueName + N' with activation (status = off);'
				end
			)
		) s(Ordinal, ObjectType, ObjectName, GeneratedScript)
		-- Deployed state for drift detection. Modules come from object_definition; Queue, Service and
		-- ActivatorBinding are scripted back from the catalogs in the template's exact format, so the
		-- comparable information lines up character-for-character with the generated Script.
		outer apply (select ExistingScript = case s.ObjectType
			when 'Queue' then
				(select N'create queue ' + v.QueueName + N' with status = ' + iif(q.is_receive_enabled = 1, N'on', N'off')
						+ N', retention = ' + iif(q.is_retention_enabled = 1, N'on', N'off')
						+ N', poison_message_handling (status = ' + iif(q.is_poison_message_handling_enabled = 1, N'on', N'off') + N');'
					from sys.service_queues q where q.object_id = object_id(v.QueueName))
			when 'Service' then
				(select N'create service ' + quotename(sv.name collate database_default) + N' on queue '
						+ schema_name(q.schema_id) collate database_default + N'.' + q.name collate database_default
						+ N' (' + (select string_agg(quotename(sc.name collate database_default), N', ') from sys.service_contract_usages u
									inner join sys.service_contracts sc on sc.service_contract_id = u.service_contract_id
									where u.service_id = sv.service_id) + N');'
					from sys.services sv
						inner join sys.service_queues q on q.object_id = sv.service_queue_id
					where sv.name collate database_default = s.ObjectName)
			when 'ActivatorBinding' then
				(select case when q.is_activation_enabled = 1 and q.activation_procedure is not null
						then N'if not exists (select 1 from sys.service_queues where object_id = object_id(''' + v.QueueName + N''') and is_activation_enabled = 1 and object_id(activation_procedure) = object_id(''' + a.ActualProcedure + N''') and max_readers = ' + cast(q.max_readers as nvarchar(10)) + N')' + f.nl +
							f.t1 + N'alter queue ' + v.QueueName + N' with activation (status = on, procedure_name = ' + a.ActualProcedure + N', max_queue_readers = ' + cast(q.max_readers as nvarchar(10)) + N', execute as owner);'
						else N'if exists (select 1 from sys.service_queues where object_id = object_id(''' + v.QueueName + N''') and is_activation_enabled = 1)' + f.nl +
							f.t1 + N'alter queue ' + v.QueueName + N' with activation (status = off);'
					end
					from sys.service_queues q
						outer apply (select ActualProcedure = object_schema_name(object_id(q.activation_procedure)) collate database_default + N'.' + object_name(object_id(q.activation_procedure)) collate database_default) a
					where q.object_id = object_id(v.QueueName))
			else object_definition(object_id(s.ObjectName)) end) e
