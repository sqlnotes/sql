/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/050-AsyncChannel/baseline/1020%20Tables/z.AsyncChannelLog.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/050-AsyncChannel/docs/reference/z.AsyncChannelLog.md

Persisted diagnostic messages on shared bigint partitions.
*/
if object_id('z.AsyncChannelLog', 'U') is null
begin
	create table z.AsyncChannelLog
	(
		LogID bigint not null constraint DF_z_AsyncChannelLog_LogID default (datediff_big(second,'1900-01-01',getutcdate())*(268435456)|next value for [z].[SeqGeneralID]),
		AsyncChannelID int,
		Level varchar(20),
		Info nvarchar(max),
		Payload nvarchar(max),
		SessionID smallint,
		ConversationHandle uniqueidentifier,
		constraint PK_z_AsyncChannelLog primary key clustered (LogID)
	) on PS_SchemaZPartitionGeneric(LogID);
end
