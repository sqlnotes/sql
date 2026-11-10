/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/050-AsyncChannel/modules/1040%20Procedures/z.usp_AsyncChannelLogFlush.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/050-AsyncChannel/docs/reference/z.usp_AsyncChannelLogFlush.md

Drains buffered logs when no transaction is open.
*/
create or alter procedure z.usp_AsyncChannelLogFlush
as
begin
	set nocount on
	if @@trancount > 0
		return
	declare @Count int = isnull(cast(session_context(N'AsyncChannel-LogCount') as int), 0), @Index int = 1,
			@InfoKey sysname, @PayloadKey sysname, @MetaKey sysname, @Meta nvarchar(400), @Info nvarchar(4000)
	while @Index <= @Count and @Index <= 40
	begin
		select	@InfoKey = N'AsyncChannel-LogInfo-' + cast(@Index as nvarchar(10)), @PayloadKey = N'AsyncChannel-LogPayload-' + cast(@Index as nvarchar(10)),
				@MetaKey = N'AsyncChannel-LogMeta-' + cast(@Index as nvarchar(10))
		select @Meta = cast(session_context(@MetaKey) as nvarchar(400))
		insert into z.AsyncChannelLog (AsyncChannelID, Level, Info, Payload, SessionID, ConversationHandle)
			values (json_value(@Meta, '$.c'), json_value(@Meta, '$.l'), cast(session_context(@InfoKey) as nvarchar(4000)), cast(session_context(@PayloadKey) as nvarchar(4000)), json_value(@Meta, '$.s'), json_value(@Meta, '$.h'))
		exec sys.sp_set_session_context @key = @InfoKey, @value = null
		exec sys.sp_set_session_context @key = @PayloadKey, @value = null
		exec sys.sp_set_session_context @key = @MetaKey, @value = null
		select @Index = @Index + 1
	end
	if @Count > 40
	begin
		select @Info = N'AsyncChannel log buffer: ' + cast(@Count - 40 as nvarchar(10)) + N' further rows were dropped (40 slots).'
		insert into z.AsyncChannelLog (AsyncChannelID, Level, Info, SessionID)
			values (json_value(@Meta, '$.c'), 'Warning', @Info, json_value(@Meta, '$.s'))
	end
	exec sys.sp_set_session_context @key = N'AsyncChannel-LogCount', @value = null
end
