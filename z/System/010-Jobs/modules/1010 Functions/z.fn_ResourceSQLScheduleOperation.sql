/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/010-Jobs/modules/1010%20Functions/z.fn_ResourceSQLScheduleOperation.sql
*/
create or alter function z.fn_ResourceSQLScheduleOperation()
returns nvarchar(100)
as
begin
	return N'z.fn_ResourceSQLScheduleOperation'
end