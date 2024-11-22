create or alter function z.fn_GetColumnReferencesFromQueryPlan(@Plan xml)
returns table
as
return (
		select distinct 
			c.value('(@Server)[1]', 'nvarchar(200)') as ServerName, 
			c.value('(@Database)[1]', 'nvarchar(200)') as DatabaseName, 
			c.value('(@Schema)[1]', 'nvarchar(200)') as SchemaName, 
			c.value('(@Table)[1]', 'nvarchar(200)') as TableName, 
			c.value('(@Column)[1]', 'nvarchar(200)') as ColumnName
		from @Plan.nodes('//*[local-name()="ColumnReference"]') as t(c)
	)
