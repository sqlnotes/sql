/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/050-AsyncChannel/modules/1050%20ServiceBroker/Sender.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/050-AsyncChannel/docs/reference/z.AsyncChannelSenderQueue.md#activation

Binds the shared sender queue to its activation procedure.
*/
if not exists
(
	select 1 from sys.service_queues
	where object_id = object_id('z.AsyncChannelSenderQueue') and is_activation_enabled = 1
		and object_id(activation_procedure) = object_id('z.usp_AsyncChannelSenderActivator')
		and max_readers = 1 and execute_as_principal_id = -2
)
	alter queue z.AsyncChannelSenderQueue with activation (status = on, procedure_name = z.usp_AsyncChannelSenderActivator, max_queue_readers = 1, execute as owner);
