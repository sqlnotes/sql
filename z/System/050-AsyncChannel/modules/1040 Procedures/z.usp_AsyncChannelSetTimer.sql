/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/050-AsyncChannel/modules/1040%20Procedures/z.usp_AsyncChannelSetTimer.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/050-AsyncChannel/docs/reference/z.usp_AsyncChannelSetTimer.md

Arms or replaces an endpoint conversation timer.
*/
-- Arms a Service Broker conversation timer on one conversation of an AsyncChannel queue. When it expires, Service Broker
-- puts a DialogTimer message (IsPayload = 0, MessageTypeID = session_context('AsyncChannel-TimerTypeID'), Payload null) on
-- the queue that owns @ConversationHandle, which wakes the activator and reaches the channel's Processing procedure.
-- The timer is local to the endpoint: the other side of the conversation sees nothing. Each endpoint holds at most one
-- pending timer; arming again replaces it, ending the conversation removes it. There is no cancel (timeout 0 is rejected
-- by SQL Server), so arm a far timeout when the wake-up is no longer wanted. The timer starts when the calling
-- transaction commits; a rollback leaves the previous timer in place.
create or alter procedure z.usp_AsyncChannelSetTimer
(
	@ConversationHandle uniqueidentifier,
	@TimeoutSeconds int
)
as
begin
	set nocount, xact_abort on;
	declare @ErrMsg nvarchar(2048);
	if @TimeoutSeconds is null or @TimeoutSeconds < 1
	begin
		set @ErrMsg = N'AsyncChannel timer: @TimeoutSeconds must be at least 1 (received ' + isnull(cast(@TimeoutSeconds as nvarchar(11)), N'null') + N'); a pending timer cannot be cancelled, only replaced.';
		throw 50000, @ErrMsg, 1;
	end
	if not exists (select 1 from sys.conversation_endpoints where conversation_handle = @ConversationHandle and state in ('SO', 'SI', 'CO'))
	begin
		set @ErrMsg = N'AsyncChannel timer: conversation ' + isnull(cast(@ConversationHandle as nvarchar(36)), N'null') + N' is not an open conversation of this database.';
		throw 50000, @ErrMsg, 1;
	end
	begin conversation timer (@ConversationHandle) timeout = @TimeoutSeconds;
end
