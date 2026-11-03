/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/010-Jobs/modules/1010%20Functions/z.fn_GetServiceJobID.sql
*/
create or alter function z.fn_GetServiceJobID(@Name nvarchar(255))
returns uniqueidentifier
as
begin
	return (select job_id from msdb.dbo.sysjobs where name = z.fn_GetServiceJobName(@Name)) 
end