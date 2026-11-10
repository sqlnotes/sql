/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/050-AsyncChannel/baseline/1030%20ServiceBroker/MessageAndContract.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/050-AsyncChannel/docs/reference/SchemaZ.AsyncChannel.Message.md
Related documentation: https://github.com/sqlnotes/sql/blob/main/z/System/050-AsyncChannel/docs/reference/SchemaZ.AsyncChannel.Contract.md

Creates the shared AsyncChannel Service Broker message type and contract when missing.
*/
if not exists (select 1 from sys.service_message_types where name = N'/SchemaZ/AsyncChannel/Message')
	create message type [/SchemaZ/AsyncChannel/Message] validation = none;
if not exists (select 1 from sys.service_contracts where name = N'/SchemaZ/AsyncChannel/Contract')
	create contract [/SchemaZ/AsyncChannel/Contract] ([/SchemaZ/AsyncChannel/Message] sent by initiator);
