/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/modules/1010%20Functions/z.fn_IsAmazonRDS.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/docs/reference/functions.md#zfn_isamazonrds

Checks the server-name pattern and visible RDS configuration object to infer Amazon RDS hosting.
*/
create or alter function z.fn_IsAmazonRDS()
returns bit
as
begin
	if @@servername like 'EC2AMAZ%%' and object_id('rdsadmin.dbo.rds_configuration') is not null
		return 1
	return 0
end
go
