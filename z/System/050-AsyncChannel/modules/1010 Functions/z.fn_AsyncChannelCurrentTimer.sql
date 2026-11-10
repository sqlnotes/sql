/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/050-AsyncChannel/modules/1010%20Functions/z.fn_AsyncChannelCurrentTimer.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/050-AsyncChannel/docs/reference/z.fn_AsyncChannelCurrentTimer.md

Remaining seconds for a committed endpoint timer.
*/
-- Seconds left on the conversation timer of one queue endpoint (sys.conversation_endpoints.dialog_timer, UTC). Null when
-- the handle is not an open conversation of this database or no timer is pending (dialog_timer is 1900-01-01, which is
-- also what it reads once the DialogTimer message has been queued). An overdue timer whose message is not queued yet is
-- reported as 0. Only timers of committed transactions are visible.
create or alter function z.fn_AsyncChannelCurrentTimer
(
	@ConversationHandle uniqueidentifier
)
returns int
with returns null on null input
as
begin
	return
	(
		select iif(e.dialog_timer > '1900-01-01', iif(datediff(second, sysutcdatetime(), e.dialog_timer) < 0, 0, datediff(second, sysutcdatetime(), e.dialog_timer)), null)
		from sys.conversation_endpoints e
		where e.conversation_handle = @ConversationHandle and e.state in ('SO', 'SI', 'CO')
	)
end
