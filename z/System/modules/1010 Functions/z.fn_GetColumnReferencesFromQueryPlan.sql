/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/modules/1010%20Functions/z.fn_GetColumnReferencesFromQueryPlan.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/docs/reference/functions.md#zfn_getcolumnreferencesfromqueryplan

Extracts distinct non-null database, schema, object and column references from execution-plan
XML ColumnReference nodes.
*/
create or alter function z.fn_GetColumnReferencesFromQueryPlan(@ExecutionPlan xml)
returns table
as
return (
		select * 
		from (
				select distinct 
					replace(replace(c.value('(@Server)[1]', 'nvarchar(200)'), '[',''), ']', '') as ServerName, 
					replace(replace(c.value('(@Database)[1]', 'nvarchar(200)'), '[',''), ']', '') as DatabaseName, 
					replace(replace(c.value('(@Schema)[1]', 'nvarchar(200)'), '[',''), ']', '') as SchemaName, 
					replace(replace(c.value('(@Table)[1]', 'nvarchar(200)'), '[',''), ']', '') as ObjectName, 
					replace(replace(c.value('(@Column)[1]', 'nvarchar(200)'), '[',''), ']', '') as ColumnName
				from @ExecutionPlan.nodes('//*[local-name()="ColumnReference"]') as t(c)
			)a
		where DatabaseName is not null
			and SchemaName is not null
			and ObjectName is not null
			and ColumnName is not null
	)
