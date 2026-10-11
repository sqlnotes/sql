create or alter procedure z.usp_DropObject
(
    @ObjectName nvarchar(512) = null
)
as
begin
    set nocount on
	declare @SQL nvarchar(max)
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
						from sys.objects o
							inner join sys.schemas s on s.schema_id = o.schema_id
							left join sys.objects p on p.object_id = o.parent_object_id
						where o.object_id = object_id(@ObjectName)
					)
    
    exec(@SQL)
end
go

