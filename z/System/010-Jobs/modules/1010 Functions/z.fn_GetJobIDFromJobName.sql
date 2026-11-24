/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/010-Jobs/modules/1010%20Functions/z.fn_GetJobIDFromJobName.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/010-Jobs/docs/reference/supporting-objects.md#zfn_getjobidfromjobname

Extracts a SQL Agent job ID from a job-step session program name.
*/
create or alter function z.fn_GetJobIDFromJobName(@JobName nvarchar(128))
returns uniqueidentifier
as
begin
    return cast(try_convert(binary(16), left(stuff(@JobName, 1, 29, ''), 34), 1) as uniqueidentifier)
end
go
