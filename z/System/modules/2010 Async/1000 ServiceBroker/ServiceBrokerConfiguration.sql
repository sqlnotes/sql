

if not exists(select * from sys.service_message_types where name = 'z.async.m-payload')
begin
	create message type [z.async.m-payload] validation = none
end
if not exists(select * from sys.service_message_types where name = 'z.async.m-log')
begin
	create message type [z.async.m-log] validation = none
end
if not exists(select * from sys.service_contracts where name = 'z.async.c-log')
begin
	create contract [z.async.c-log] ([z.async.m-log] sent by initiator)
end


if object_id('z.usp_AsyncSenderActivator') is null
begin
	exec('create or alter procedure z.usp_AsyncSenderActivator
as
begin
	set nocount on;
	declare @handle uniqueidentifier, @Body varbinary(max), @MessageType varchar(256)
	waitfor ( 
			    receive top(1) @handle = conversation_handle, @MessageType = message_type_name 
				from z.AsyncSender
			), timeout 1000;
	if @handle is null
		return;

	if @MessageType = ''http://schemas.microsoft.com/SQL/ServiceBroker/EndDialog''
	begin
		end conversation @handle;
		delete z.AsyncConversation where InitiatorHandle = @handle;
	end
end')
end
if not exists(select * from sys.service_queues where schema_id = schema_id('z') and name = 'AsyncSender')
begin
	create queue z.AsyncSender with status = on, retention = off, poison_message_handling (status = on), 
		activation (
						status = on , 
						procedure_name = z.usp_AsyncSenderActivator , 
						max_queue_readers = 10 , 
						execute as owner
				)
end
if not exists(select * from sys.services where name = 'z.Async.sender')
begin
	create service [z.Async.sender] on queue z.AsyncSender([z.async.c-log]);
end