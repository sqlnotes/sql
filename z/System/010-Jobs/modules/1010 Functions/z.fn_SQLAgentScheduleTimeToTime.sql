/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/010-Jobs/modules/1010%20Functions/z.fn_SQLAgentScheduleTimeToTime.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/010-Jobs/docs/reference/supporting-objects.md#zfn_sqlagentscheduletimetotime

Converts a SQL Agent HHMMSS integer into a SQL time value.
*/
create or alter function z.fn_SQLAgentScheduleTimeToTime(@Time as int)
returns time(0)
as
begin
	return (
				select left(t.i, 2) + ':' + substring(t.i, 3, 2) + ':' + right(t.i, 2)
				from (select right('000000' + cast(@Time as varchar(100)), 6) i ) t
			)
			
end