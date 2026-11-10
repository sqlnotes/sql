/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/050-AsyncChannel/modules/1040%20Procedures/z.usp_AsyncChannelSend.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/050-AsyncChannel/docs/reference/z.usp_AsyncChannelSend.md

Sends serialized fragments and retries one stale-conversation failure.
*/
create or alter procedure z.usp_AsyncChannelSend
(
	@AsyncChannelID int,
	@Data nvarchar(max),
	@ConversationHandle uniqueidentifier = null output
)
as
begin
	set nocount on
	declare @Attempt int = 0, @ErrMsg nvarchar(2048)

	if @ConversationHandle is null
		exec z.usp_AsyncChannelGetConversationHandle @AsyncChannelID = @AsyncChannelID, @ConversationHandle = @ConversationHandle output
	if @ConversationHandle is null
	begin
		-- an inactive channel discards the message silently; an unknown channel is logged, never raised
		if exists (select 1 from z.AsyncChannel where AsyncChannelID = @AsyncChannelID)
			return
		select @ErrMsg = N'AsyncChannel send: unknown AsyncChannelID ' + isnull(cast(@AsyncChannelID as nvarchar(10)), N'null') + N'; message discarded.'
		exec z.usp_AsyncChannelLog @AsyncChannelID = @AsyncChannelID, @Level = 'Error', @Info = @ErrMsg, @Payload = @Data, @SessionID = @@spid
		return
	end

	while @Attempt < 2
	begin
		begin try
			;send on conversation @ConversationHandle message type [/SchemaZ/AsyncChannel/Message] (@Data);
			break;
		end try
		begin catch
			if error_number() = 8426 and @Attempt = 0
			begin
				delete from z.AsyncChannelSession where AsyncChannelID = @AsyncChannelID and SessionID = @@spid;
				select @ConversationHandle = null
				exec z.usp_AsyncChannelGetConversationHandle @AsyncChannelID = @AsyncChannelID, @ConversationHandle = @ConversationHandle output;
				if @ConversationHandle is null
					return
				select @Attempt = @Attempt + 1
			end
			else
				throw;
		end catch
	end
end
