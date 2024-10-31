/*
This procedure drop all local temp tables created incurrent session
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
