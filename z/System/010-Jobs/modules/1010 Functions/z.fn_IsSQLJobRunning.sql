/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/010-Jobs/modules/1010%20Functions/z.fn_IsSQLJobRunning.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/010-Jobs/docs/reference/supporting-objects.md#zfn_issqljobrunning

Checks visible local sessions for a SQL Agent T-SQL job-step application name containing the native job ID.
*/
create or alter function z.fn_IsSQLJobRunning(@JobID uniqueidentifier)
returns bit
as
begin
	return case when exists
	(
		select	1 from sys.dm_exec_sessions s
		where s.program_name like N'SQLAgent - TSQL JobStep (Job '
			+ convert(nvarchar(34), convert(binary(16), @JobID), 1) + N' : Step %)'
	) then 1 else 0 end;
end;
