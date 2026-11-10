/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/050-AsyncChannel/baseline/1040%20ServiceBroker/SenderInfrastructure.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/050-AsyncChannel/docs/reference/z.AsyncChannelSenderQueue.md
Related documentation: https://github.com/sqlnotes/sql/blob/main/z/System/050-AsyncChannel/docs/reference/SchemaZ.AsyncChannel.Sender.md

Creates the shared sender reply queue and service when missing.
*/
if object_id('z.AsyncChannelSenderQueue', 'SQ') is null
	create queue z.AsyncChannelSenderQueue with status = on, retention = off, poison_message_handling (status = off);
if not exists (select 1 from sys.services where name = N'/SchemaZ/AsyncChannel/Sender')
	create service [/SchemaZ/AsyncChannel/Sender] on queue z.AsyncChannelSenderQueue ([/SchemaZ/AsyncChannel/Contract]);
