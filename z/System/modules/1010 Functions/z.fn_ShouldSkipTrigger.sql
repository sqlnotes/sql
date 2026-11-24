/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/modules/1010%20Functions/z.fn_ShouldSkipTrigger.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/docs/reference/functions.md#zfn_shouldskiptrigger

Checks whether the session-context trigger-skip flag includes a supplied trigger or all
triggers.
*/
create or alter function z.fn_ShouldSkipTrigger(@TriggerID int)
returns bit
as
begin
	if cast(session_context(N'SkipTriggerFlag') as nvarchar(4000)) = N'all'
		return 1;
	return isnull(
					(
						select	1
						from string_split(cast(session_context(N'SkipTriggerFlag') as nvarchar(4000)), N',')
						where value = cast(@TriggerID as nvarchar(4000))
					)
				, 0)
end
