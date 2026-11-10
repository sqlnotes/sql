/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/050-AsyncChannel/baseline/1010%20Types/z.AsyncChannelMessage.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/050-AsyncChannel/docs/reference/z.AsyncChannelMessage.md

Readonly payload, control and timer message table type.
*/
if type_id('z.AsyncChannelMessage') is null
begin
	exec(N'create type z.AsyncChannelMessage as table
	(
		ConversationHandle uniqueidentifier not null,
		MessageTypeID int not null,
		SequenceNumber bigint not null,
		IsPayload bit not null,
		Payload nvarchar(max)
	)');
end
