create or alter procedure z.usp_RemoveSchemaZ
(
	@Confirm bit = 0
)
as
begin
	set nocount on
	if isnull(@Confirm, 0) = 0
	begin
		raiserror('Please confirm removing z schema by passing value 1', 16, 1)
		return
	end
	declare @SQL nvarchar(max)	
	declare c cursor local local for
		select 'exec sp_control_plan_guide N''DROP'', N'+quotename(name, '''')+';'   from sys.plan_guides where object_schema_name(scope_object_id) = 'z'
	open c
	fetch next from c into @SQL
	while @@fetch_status = 0
	begin
		exec(@SQL)
		fetch next from c into @SQL
	end
	close c
	deallocate c
	while 1=1
	begin
		;with x0 as
		(
			select o.object_id, o.parent_object_id, 1 Level, o.type_desc
			from sys.objects o
			where schema_id = schema_id('z')
				and parent_object_id = 0
				and o.object_id <> @@procid
			union all
			select o.object_id, o.parent_object_id, x0.Level + 1, o.type_desc
			from sys.objects o
				inner join x0 on o.parent_object_id = x0.object_id
			where o.schema_id = schema_id('z')
				and x0.type_desc not in('SQL_TABLE_VALUED_FUNCTION')
				and o.object_id <> @@procid
		),
		x1 as
		(
			select top 1 *
			from x0
			order by Level desc
		)
		select @SQL = (
						select case o.type_desc
									when 'AGGREGATE_FUNCTION' then 'drop aggregate ' + quotename(s.name) + '.' + quotename(o.name)
									when 'CHECK_CONSTRAINT' then 'alter table' + quotename(s.name) + '.' + quotename(p.name) + ' drop constraint ' + quotename(o.name)
									when 'CLR_SCALAR_FUNCTION' then 'drop function ' + quotename(s.name) + '.' + quotename(o.name)
									when 'CLR_STORED_PROCEDURE' then 'drop procedure ' + quotename(s.name) + '.' + quotename(o.name)
									when 'CLR_TABLE_VALUED_FUNCTION' then 'drop function ' + quotename(s.name) + '.' + quotename(o.name)
									when 'CLR_TRIGGER' then 'drop trigger ' + quotename(s.name) + '.' + quotename(o.name)
									when 'DEFAULT_CONSTRAINT' then 'alter table' + quotename(s.name) + '.' + quotename(p.name) + ' drop constraint ' + quotename(o.name)
									when 'EDGE_CONSTRAINT' then 'alter table' + quotename(s.name) + '.' + quotename(p.name) + ' drop constraint ' + quotename(o.name)
									when 'EXTENDED_STORED_PROCEDURE' then 'drop procedure ' + quotename(s.name) + '.' + quotename(o.name)
									when 'FOREIGN_KEY_CONSTRAINT' then 'alter table' + quotename(s.name) + '.' + quotename(p.name) + ' drop constraint ' + quotename(o.name)
									when 'PRIMARY_KEY_CONSTRAINT' then 'alter table' + quotename(s.name) + '.' + quotename(p.name) + ' drop constraint ' + quotename(o.name)
									when 'REPLICATION_FILTER_PROCEDURE' then 'drop procedure ' + quotename(s.name) + '.' + quotename(o.name)
									when 'RULE' then 'drop rule ' + quotename(s.name) + '.' + quotename(o.name)
									when 'SEQUENCE_OBJECT' then 'drop sequence ' + quotename(s.name) + '.' + quotename(o.name)
									when 'SERVICE_QUEUE' then 'drop queue ' + quotename(s.name) + '.' + quotename(o.name)
									when 'SQL_INLINE_TABLE_VALUED_FUNCTION' then 'drop function ' + quotename(s.name) + '.' + quotename(o.name)
									when 'SQL_SCALAR_FUNCTION' then 'drop function ' + quotename(s.name) + '.' + quotename(o.name)
									when 'SQL_STORED_PROCEDURE' then 'drop procedure ' + quotename(s.name) + '.' + quotename(o.name)
									when 'SQL_TABLE_VALUED_FUNCTION' then 'drop function ' + quotename(s.name) + '.' + quotename(o.name)
									when 'SQL_TRIGGER' then 'drop trigger ' + quotename(s.name) + '.' + quotename(o.name)
									when 'SYNONYM' then 'drop synonym ' + quotename(s.name) + '.' + quotename(o.name)
									when 'UNIQUE_CONSTRAINT' then 'alter table' + quotename(s.name) + '.' + quotename(p.name) + ' drop constraint ' + quotename(o.name)
									when 'USER_TABLE' then 'drop table ' + quotename(s.name) + '.' + quotename(o.name)
									when 'VIEW' then 'drop view ' + quotename(s.name) + '.' + quotename(o.name)
								end + ';'
						from x1
							inner join sys.objects o on x1.object_id = o.object_id
							inner join sys.schemas s on s.schema_id = o.schema_id
							left join sys.objects p on p.object_id = o.parent_object_id
					)
		if @SQL is null
		begin
			if exists(select * from sys.partition_schemes where name = 'PS_SchemaZPartitionGeneric')
				drop partition scheme PS_SchemaZPartitionGeneric
			if exists(select * from sys.partition_functions where name = 'PF_SchemaZPartitionGeneric')
				drop partition function PF_SchemaZPartitionGeneric;
			break
		end
		begin try
		--print @SQL
		exec(@SQL)
		end try
		begin catch
		print error_message()
		end catch
	end
	drop procedure z.usp_RemoveSchemaZ;
	if schema_id('z') is not null
		exec('drop schema z;')
end
go
