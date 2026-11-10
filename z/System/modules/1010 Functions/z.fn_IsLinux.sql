/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/modules/1010%20Functions/z.fn_IsLinux.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/docs/reference/functions.md#zfn_islinux

Checks the server version string for Linux hosting.
*/
create or alter function z.fn_IsLinux()
returns bit 
as 
begin 
	return case when lower(@@version) like '%linux%' then 1 else 0 end
end
