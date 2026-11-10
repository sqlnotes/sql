/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/050-AsyncChannel/modules/1040%20Procedures/z.usp_AsyncChannelForward.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/050-AsyncChannel/docs/reference/z.usp_AsyncChannelForward.md

Forwards payload rows to configured destination IDs.
*/
create or alter procedure z.usp_AsyncChannelForward
(
	@Messages z.AsyncChannelMessage readonly,
	@AsyncChannelIDs varchar(max),
	@Batched bit = 1
)
as
begin
	set nocount on
	declare @Unknown varchar(max), @ErrMsg nvarchar(2048), @SourceAsyncChannelID int
	declare @Channels table (AsyncChannelID int not null primary key)
	insert into @Channels (AsyncChannelID)
		select distinct cast(trim(value) as int) from string_split(@AsyncChannelIDs, ',') where trim(value) <> ''
	select @Unknown = string_agg(cast(c.AsyncChannelID as varchar(10)), ', ')
	from @Channels c
	where not exists (select 1 from z.AsyncChannel a where a.AsyncChannelID = c.AsyncChannelID)
	if @Unknown is not null
	begin
		-- forwarding runs in a Service Broker session where nobody sees an error: log it and keep forwarding to the known channels
		select @ErrMsg = N'AsyncChannel forward: unknown AsyncChannelID ' + @Unknown + N'; skipped.', @SourceAsyncChannelID = cast(session_context(N'AsyncChannel-AsyncChannelID') as int)
		exec z.usp_AsyncChannelLog @AsyncChannelID = @SourceAsyncChannelID, @Level = 'Error', @Info = @ErrMsg, @SessionID = @@spid
		delete c from @Channels c where not exists (select 1 from z.AsyncChannel a where a.AsyncChannelID = c.AsyncChannelID)
	end
	if @Batched = 0
	begin
		insert into z.AsyncChannelMessage_Interface (AsyncChannelID, DataSequence, Data)
			select c.AsyncChannelID, m.SequenceNumber, m.Payload
			from @Messages m
				cross join @Channels c
			where m.IsPayload = 1
	end
	else
	begin
		insert into z.AsyncChannelMessageBatched_Interface (AsyncChannelID, DataSequence, Data)
			select c.AsyncChannelID, m.SequenceNumber, m.Payload
			from @Messages m
				cross join @Channels c
			where m.IsPayload = 1
	end
end
