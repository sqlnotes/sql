/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/modules/1070%20Procedures/z.usp_RemoveSchemaZ.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/docs/reference/procedures.md#zusp_removeschemaz

Attempts confirmed destructive removal of Schema Z objects, plan guides, shared partitions and
the schema itself.
*/
create or alter procedure z.usp_RemoveSchemaZ
(
	@Confirm bit = 0
)
as
begin
	set nocount on
	if isnull(@Confirm, 0) = 0
	begin
		throw 50000, 'Please confirm removing z schema by passing value 1', 1;
	end
	declare @SQL nvarchar(max), @ObjectID int, @Progress bit = 0;
	declare @Skipped table (object_id int primary key);
	declare cPlanGuides cursor local static for
		select 'exec sp_control_plan_guide N''DROP'', N' + quotename(name, '''') + ';' from sys.plan_guides where object_schema_name(scope_object_id) = 'z';
	open cPlanGuides;
	fetch next from cPlanGuides into @SQL;
	while @@fetch_status = 0
	begin
		exec(@SQL);
		fetch next from cPlanGuides into @SQL;
	end
	close cPlanGuides;
	deallocate cPlanGuides;
	while 1=1
	begin
		select @ObjectID = null, @SQL = null;
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
			where not exists (select 1 from @Skipped s where s.object_id = x0.object_id)
			order by x0.Level desc,
				case x0.type_desc
					when 'FOREIGN_KEY_CONSTRAINT' then 1
					when 'EDGE_CONSTRAINT' then 2
					when 'SQL_TRIGGER' then 3
					when 'CLR_TRIGGER' then 3
					when 'CHECK_CONSTRAINT' then 4
					when 'DEFAULT_CONSTRAINT' then 5
					when 'UNIQUE_CONSTRAINT' then 6
					when 'PRIMARY_KEY_CONSTRAINT' then 7
					else 8
				end,
				x0.object_id desc
		)
		select @ObjectID = x1.object_id,
			@SQL = (
						select case o.type_desc
									when 'AGGREGATE_FUNCTION' then 'drop aggregate ' + quotename(s.name) + '.' + quotename(o.name)
									when 'CHECK_CONSTRAINT' then 'alter table ' + quotename(s.name) + '.' + quotename(p.name) + ' drop constraint ' + quotename(o.name)
									when 'CLR_SCALAR_FUNCTION' then 'drop function ' + quotename(s.name) + '.' + quotename(o.name)
									when 'CLR_STORED_PROCEDURE' then 'drop procedure ' + quotename(s.name) + '.' + quotename(o.name)
									when 'CLR_TABLE_VALUED_FUNCTION' then 'drop function ' + quotename(s.name) + '.' + quotename(o.name)
									when 'CLR_TRIGGER' then 'drop trigger ' + quotename(s.name) + '.' + quotename(o.name)
									when 'DEFAULT_CONSTRAINT' then 'alter table ' + quotename(s.name) + '.' + quotename(p.name) + ' drop constraint ' + quotename(o.name)
									when 'EDGE_CONSTRAINT' then 'alter table ' + quotename(s.name) + '.' + quotename(p.name) + ' drop constraint ' + quotename(o.name)
									when 'EXTENDED_STORED_PROCEDURE' then 'drop procedure ' + quotename(s.name) + '.' + quotename(o.name)
									when 'FOREIGN_KEY_CONSTRAINT' then 'alter table ' + quotename(s.name) + '.' + quotename(p.name) + ' drop constraint ' + quotename(o.name)
									when 'PRIMARY_KEY_CONSTRAINT' then 'alter table ' + quotename(s.name) + '.' + quotename(p.name) + ' drop constraint ' + quotename(o.name)
									when 'REPLICATION_FILTER_PROCEDURE' then 'drop procedure ' + quotename(s.name) + '.' + quotename(o.name)
									when 'RULE' then 'drop rule ' + quotename(s.name) + '.' + quotename(o.name)
									when 'SEQUENCE_OBJECT' then 'drop sequence ' + quotename(s.name) + '.' + quotename(o.name)
									when 'SERVICE_QUEUE' then isnull((select string_agg('drop service ' + quotename(sv.name) + ';', '') from sys.services sv where sv.service_queue_id = o.object_id), '') + 'drop queue ' + quotename(s.name) + '.' + quotename(o.name)
									when 'SQL_INLINE_TABLE_VALUED_FUNCTION' then 'drop function ' + quotename(s.name) + '.' + quotename(o.name)
									when 'SQL_SCALAR_FUNCTION' then 'drop function ' + quotename(s.name) + '.' + quotename(o.name)
									when 'SQL_STORED_PROCEDURE' then 'drop procedure ' + quotename(s.name) + '.' + quotename(o.name)
									when 'SQL_TABLE_VALUED_FUNCTION' then 'drop function ' + quotename(s.name) + '.' + quotename(o.name)
									when 'SQL_TRIGGER' then 'drop trigger ' + quotename(s.name) + '.' + quotename(o.name)
									when 'SYNONYM' then 'drop synonym ' + quotename(s.name) + '.' + quotename(o.name)
									when 'UNIQUE_CONSTRAINT' then 'alter table ' + quotename(s.name) + '.' + quotename(p.name) + ' drop constraint ' + quotename(o.name)
									when 'USER_TABLE' then 'drop table ' + quotename(s.name) + '.' + quotename(o.name)
									when 'VIEW' then 'drop view ' + quotename(s.name) + '.' + quotename(o.name)
								end + ';'
						from sys.objects o
							inner join sys.schemas s on s.schema_id = o.schema_id
							left join sys.objects p on p.object_id = o.parent_object_id
						where o.object_id = x1.object_id
					)
		from x1;
		if @SQL is null
		begin
			if exists (select 1 from @Skipped) and @Progress = 1
			begin
				delete from @Skipped;
				select @Progress = 0;
				continue;
			end
			select @SQL = string_agg('drop type ' + quotename(s.name) + '.' + quotename(t.name) + ';', '')
			from sys.types t
				inner join sys.schemas s on s.schema_id = t.schema_id
			where t.schema_id = schema_id('z')
				and t.is_user_defined = 1;
			if @SQL is not null
				exec(@SQL);
			select @SQL = string_agg('drop xml schema collection ' + quotename(s.name) + '.' + quotename(x.name) + ';', '')
			from sys.xml_schema_collections x
				inner join sys.schemas s on s.schema_id = x.schema_id
			where x.schema_id = schema_id('z');
			if @SQL is not null
				exec(@SQL);
			if exists (select * from sys.service_contracts where name = N'/SchemaZ/AsyncChannel/Contract')
				drop contract [/SchemaZ/AsyncChannel/Contract];
			if exists (select * from sys.service_message_types where name = N'/SchemaZ/AsyncChannel/Message')
				drop message type [/SchemaZ/AsyncChannel/Message];
			if exists(select * from sys.partition_schemes where name = 'PS_SchemaZPartitionGenericDateTime')
				drop partition scheme PS_SchemaZPartitionGenericDateTime;
			if exists(select * from sys.partition_functions where name = 'PF_SchemaZPartitionGenericDateTime')
				drop partition function PF_SchemaZPartitionGenericDateTime;
			if exists(select * from sys.partition_schemes where name = 'PS_SchemaZPartitionGeneric')
				drop partition scheme PS_SchemaZPartitionGeneric;
			if exists(select * from sys.partition_functions where name = 'PF_SchemaZPartitionGeneric')
				drop partition function PF_SchemaZPartitionGeneric;
			break;
		end
		begin try
			exec(@SQL);
			select @Progress = 1;
		end try
		begin catch
			insert into @Skipped (object_id) values (@ObjectID);
			print error_message();
		end catch
	end
	drop procedure z.usp_RemoveSchemaZ;
	if schema_id('z') is not null
		exec('drop schema z;')
end
