/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/010-Jobs/modules/1010%20Functions/z.fn_GetScheduleNamePrefix.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/010-Jobs/docs/reference/z.fn_GetScheduleNamePrefix.md

Returns the schedule-name prefix for the current database.
*/
create or alter function z.fn_GetScheduleNamePrefix()
returns nvarchar(300)
as
begin
	return N'Schema z: ' + quotename(db_name()) + N': ';
end;
go
