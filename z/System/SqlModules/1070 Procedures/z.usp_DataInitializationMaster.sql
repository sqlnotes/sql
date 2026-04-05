create or alter procedure z.usp_DataInitializationMaster
(
	@SchemaName nvarchar(128) = 'z'
)
as
begin
	set nocount on
	declare @SQL nvarchar(max)
	declare c cursor local for
		select quotename(object_schema_name(object_id))+'.'+ quotename(name) 
		from sys.procedures
		where name like 'usp!_DataInitialization%' escape '!'
			and name not in ('usp_DataInitializationHelper', 'usp_DataInitializationMaster')
			and schema_id = iif(@SchemaName is null, schema_id, schema_id(@SchemaName))
		order by 1 asc
	open c
	fetch next from c into @SQL
	while @@fetch_status = 0
	begin
		print 'Executing ... ' + @SQL
		exec @SQL
		fetch next from c into @SQL
	end
	close c
	deallocate c
end