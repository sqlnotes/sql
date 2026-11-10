/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/050-AsyncChannel/modules/1040%20Procedures/z.usp_AsyncChannelLog.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/050-AsyncChannel/docs/reference/z.usp_AsyncChannelLog.md

Writes immediately or buffers diagnostic rows in session context.
*/
create or alter procedure z.usp_AsyncChannelLog
(
	@AsyncChannelID int = null,
	@Level varchar(20) = null,
	@Info nvarchar(max) = null,
	@Payload nvarchar(max) = null,
	@SessionID smallint = null,
	@ConversationHandle uniqueidentifier = null
)
as
begin
	set nocount on
	-- Buffering errors are suppressed; direct inserts and flushing can propagate errors.
	-- Outside a transaction the row is inserted directly, after draining any buffer left in session context.
	-- Debug rows describe a batch that succeeded: they are inserted directly and go with the transaction (skipped when it
	-- is doomed). Any other row inside a transaction is kept only in session context, which survives a rollback; it is
	-- written by z.usp_AsyncChannelLogFlush once no transaction is open.
	-- Session-context values are sql_variant: nvarchar(max) must be copied into nvarchar(4000) variables first.
	declare @Count int, @Key sysname, @Meta nvarchar(400), @InfoValue nvarchar(4000), @PayloadValue nvarchar(4000)
	if @@trancount = 0 or isnull(@Level, '') = 'Debug'
	begin
		if xact_state() <> -1
		begin
			exec z.usp_AsyncChannelLogFlush
			insert into z.AsyncChannelLog (AsyncChannelID, Level, Info, Payload, SessionID, ConversationHandle)
				values (@AsyncChannelID, @Level, @Info, @Payload, @SessionID, @ConversationHandle)
		end
		return
	end

	begin try
		select @Count = isnull(cast(session_context(N'AsyncChannel-LogCount') as int), 0) + 1
		if @Count <= 40
		begin
			select @Meta = (select @AsyncChannelID c, @Level l, @SessionID s, @ConversationHandle h for json path, without_array_wrapper)
			select @Key = N'AsyncChannel-LogInfo-' + cast(@Count as nvarchar(10)), @InfoValue = left(@Info, 4000)
			exec sys.sp_set_session_context @key = @Key, @value = @InfoValue
			select @Key = N'AsyncChannel-LogPayload-' + cast(@Count as nvarchar(10)), @PayloadValue = left(@Payload, 4000)
			exec sys.sp_set_session_context @key = @Key, @value = @PayloadValue
			select @Key = N'AsyncChannel-LogMeta-' + cast(@Count as nvarchar(10))
			exec sys.sp_set_session_context @key = @Key, @value = @Meta
		end
		-- rows beyond the 40 slots are dropped, but counted so the flush can report them
		exec sys.sp_set_session_context @key = N'AsyncChannel-LogCount', @value = @Count
	end try
	begin catch
	end catch
end
