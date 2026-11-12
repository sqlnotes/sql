/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/050-AsyncChannel/baseline/1020%20Tables/z.AsyncChannelSession.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/050-AsyncChannel/docs/reference/z.AsyncChannelSession.md

Per-channel, per-session reusable conversations.
*/
if object_id('z.AsyncChannelSession', 'U') is null
begin
	create table z.AsyncChannelSession
	(
		AsyncChannelID int not null,
		SessionID smallint not null,
		GroupBucket smallint not null,
		ConversationHandle uniqueidentifier not null,
		StartTimeUTC datetime2(7) not null,
		index IX_z_AsyncChannelSession_AsyncChannelID_GroupBucket nonclustered (AsyncChannelID, GroupBucket),
		constraint PK_z_AsyncChannelSession primary key clustered (AsyncChannelID, SessionID),
		constraint UQ_z_AsyncChannelSession_ConversationHandle unique nonclustered (ConversationHandle)
	);
end
