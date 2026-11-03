/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/010-Jobs/modules/1010%20Functions/z.fn_IsSQLAgentRunning.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/010-Jobs/docs/reference/supporting-objects.md#zfn_issqlagentrunning

Checks visible sessions for a SQL Agent program name.
*/
create or alter function z.fn_IsSQLAgentRunning()
returns int -- use int for future extension.
as
begin
	return case when not exists(select * from sys.dm_exec_sessions where program_name like '%SQLAgent%') then 0 else 1 end
end