/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/050-AsyncChannel/modules/1040%20Procedures/z.usp_AsyncChannelSenderActivator.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/050-AsyncChannel/docs/reference/z.usp_AsyncChannelSenderActivator.md

Consumes sender-side end/error messages and clears session registry entries.
*/
create or alter procedure z.usp_AsyncChannelSenderActivator
as
begin
	set nocount on
	declare @Handle uniqueidentifier, @MessageType sysname, @ChannelID int, @SessionID smallint,@BodyText nvarchar(max)

	while (1 = 1)
	begin
		select @Handle = null, @ChannelID = null, @SessionID = null;
		waitfor (
					receive top(1) @Handle = conversation_handle, @MessageType = message_type_name, @BodyText = cast(message_body as nvarchar(max))
					from z.AsyncChannelSenderQueue
				), timeout 1100;
		if @Handle is null
			break;

		select @ChannelID = AsyncChannelID, @SessionID = SessionID
		from z.AsyncChannelSession
		where ConversationHandle = @Handle;

		if @MessageType in (N'http://schemas.microsoft.com/SQL/ServiceBroker/Error', N'http://schemas.microsoft.com/SQL/ServiceBroker/EndDialog')
		begin
			end conversation @Handle;
			delete from z.AsyncChannelSession where ConversationHandle = @Handle;
			if @MessageType in (N'http://schemas.microsoft.com/SQL/ServiceBroker/Error')
			begin
				exec z.usp_AsyncChannelLog @AsyncChannelID = @ChannelID, @Level = 'Error', @Info = N'sender: conversation error', @Payload = @BodyText, @SessionID = @SessionID, @ConversationHandle = @Handle;
			end
			else
			begin
				exec z.usp_AsyncChannelLog @AsyncChannelID = @ChannelID, @Level = 'Info', @Info = N'sender: dialog is end', @Payload = @BodyText, @SessionID = @SessionID, @ConversationHandle = @Handle;
			end
		end
	end
end
