/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/modules/1010%20Functions/z.fn_IsAzureDatabase.sql
*/
create or alter function z.fn_IsAzureDatabase()
returns bit
as
begin
	if @@version like '%Microsoft SQL Azure%'
		return 0
	return 0
end