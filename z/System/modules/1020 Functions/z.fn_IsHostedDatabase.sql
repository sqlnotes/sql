/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/modules/1020%20Functions/z.fn_IsHostedDatabase.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/docs/reference/functions.md#zfn_ishosteddatabase

Combines the Amazon RDS and Azure helper results to report inferred database hosting.
*/
create or alter function z.fn_IsHostedDatabase()
returns bit
as
begin
	if z.fn_IsAmazonRDS() = 1
		return 1
	if z.fn_IsAzureDatabase() = 1
		return 1
	return 0
end