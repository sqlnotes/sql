/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/modules/1010%20Functions/z.fn_IsAzureDatabase.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/docs/reference/functions.md#zfn_isazuredatabase

Identifies Azure SQL Database and Azure SQL Managed Instance by engine edition.
*/
create or alter function z.fn_IsAzureDatabase()
returns bit
as
begin
	return iif(serverproperty('EngineEdition') in (5, 8), 1, 0);
end;
