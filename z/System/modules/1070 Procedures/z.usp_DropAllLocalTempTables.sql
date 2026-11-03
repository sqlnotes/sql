/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/modules/1070%20Procedures/z.usp_DropAllLocalTempTables.sql
*/
create or alter procedure z.usp_DropAllLocalTempTables
as
begin
	set nocount on
	exec tempdb..sp_executesql N'declare @SQL nvarchar(max)
	select @SQL = (
	select distinct  ''drop table '' + quotename(schema_name(schema_id)) + ''.'' + quotename(name) + '';''
	from tempdb.sys.tables
	where name like ''#%''
		and name not like ''##%''
		and object_id(quotename(schema_name(schema_id)) + ''.'' + quotename(name)) is not null
	for xml path(''''), type).value(''.'', ''nvarchar(max)'')
	exec(@SQL)'
end;
