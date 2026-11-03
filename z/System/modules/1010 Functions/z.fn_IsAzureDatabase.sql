/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/modules/1010%20Functions/z.fn_IsAzureDatabase.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/docs/reference/functions.md#zfn_isazuredatabase

Provides the Azure-detection helper interface but currently returns zero for every server.
*/
create or alter function z.fn_IsAzureDatabase()
returns bit
as
begin
	if @@version like '%Microsoft SQL Azure%'
		return 0
	return 0
end