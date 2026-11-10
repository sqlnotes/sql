/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/050-AsyncChannel/modules/1060%20Triggers/z.TRI_AsyncChannelMessage_Interface.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/050-AsyncChannel/docs/reference/z.TRI_AsyncChannelMessage_Interface.md

Routes inserted fragments to the send helper.
*/
create or alter trigger z.TRI_AsyncChannelMessage_Interface on z.AsyncChannelMessage_Interface
instead of insert
as
begin
	set nocount on
	if not exists (select 1 from inserted)
		return

	declare @AsyncChannelID int, @LastAsyncChannelID int, @Data nvarchar(max), @Handle uniqueidentifier
	declare c cursor local fast_forward for
		select AsyncChannelID, Data from inserted order by AsyncChannelID, DataSequence
	open c
	fetch next from c into @AsyncChannelID, @Data
	while @@fetch_status = 0
	begin
		if @LastAsyncChannelID is null or @AsyncChannelID is null or @LastAsyncChannelID <> @AsyncChannelID
		begin
			select @LastAsyncChannelID = @AsyncChannelID, @Handle = null
			exec z.usp_AsyncChannelGetConversationHandle @AsyncChannelID = @AsyncChannelID, @ConversationHandle = @Handle output
		end
		if @Handle is not null
			exec z.usp_AsyncChannelSend @AsyncChannelID = @AsyncChannelID, @Data = @Data, @ConversationHandle = @Handle output
		fetch next from c into @AsyncChannelID, @Data
	end
	close c
	deallocate c
end
