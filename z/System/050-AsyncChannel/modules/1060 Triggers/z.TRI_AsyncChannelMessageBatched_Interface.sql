/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/050-AsyncChannel/modules/1060%20Triggers/z.TRI_AsyncChannelMessageBatched_Interface.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/050-AsyncChannel/docs/reference/z.TRI_AsyncChannelMessageBatched_Interface.md

Chunks and routes inserted fragments to the send helper.
*/
create or alter trigger z.TRI_AsyncChannelMessageBatched_Interface on z.AsyncChannelMessageBatched_Interface
instead of insert
as
begin
	set nocount on
	if not exists (select 1 from inserted)
		return

	declare @AsyncChannelID int, @LastAsyncChannelID int, @Payload nvarchar(max), @Handle uniqueidentifier
	declare Messages cursor local static for
		select r.AsyncChannelID, string_agg(r.Data, N',') within group (order by r.DataSequence)
		from (
				select	ChunkID = (row_number() over (partition by i.AsyncChannelID order by i.DataSequence) - 1) / isnull(c.MaxRowsPerMessage, 2147483647),
						i.AsyncChannelID, i.DataSequence, i.Data
				from inserted i
					inner join z.AsyncChannel c on c.AsyncChannelID = i.AsyncChannelID
				where c.IsActive = 1
			) r
		group by r.AsyncChannelID, r.ChunkID
		order by r.AsyncChannelID, r.ChunkID
	open Messages
	fetch next from Messages into @AsyncChannelID, @Payload
	while @@fetch_status = 0
	begin
		if @LastAsyncChannelID is null or @LastAsyncChannelID <> @AsyncChannelID
		begin
			select @LastAsyncChannelID = @AsyncChannelID, @Handle = null
			exec z.usp_AsyncChannelGetConversationHandle @AsyncChannelID = @AsyncChannelID, @ConversationHandle = @Handle output
		end
		if @Handle is not null
			exec z.usp_AsyncChannelSend @AsyncChannelID = @AsyncChannelID, @Data = @Payload, @ConversationHandle = @Handle output
		fetch next from Messages into @AsyncChannelID, @Payload
	end
	close Messages
	deallocate Messages
end
