create or alter view z.v_Objects
as
	select 
		cast(o.object_id as int) ObjectID, 
		schema_name(o.schema_id) SchemaName,
		o.name ObjectName,
		o.type_desc ObjectType,
		c.column_id ColumnID,
		c.name ColumnName,
		cast(isnull(ic.key_ordinal,0) as int) PrimaryKeyOrder, 
		c.max_length DataLength,
		case when isnull(type_name(c.system_type_id), type_name(c.user_type_id)) = 'timestamp' then 'binary(8)' else isnull(type_name(c.system_type_id), type_name(c.user_type_id)) end +
		case 
			when isnull(type_name(c.system_type_id), type_name(c.user_type_id)) in ('binary', 'char') then '('+cast(c.max_length as varchar(20))+')'
			when isnull(type_name(c.system_type_id), type_name(c.user_type_id)) in ('nchar') then '('+cast(c.max_length / 2 as varchar(20))+')'
			when isnull(type_name(c.system_type_id), type_name(c.user_type_id)) in ('datetime2', 'datetimeoffset', 'time') then '('+cast(c.scale as varchar(20))+')'
			when isnull(type_name(c.system_type_id), type_name(c.user_type_id)) in ('decimal', 'numeric') then '('+cast(c.precision as varchar(20))+','+cast(c.scale as varchar(20))+')'
			when isnull(type_name(c.system_type_id), type_name(c.user_type_id)) in ('varchar') then '('+case when c.max_length = -1 then 'max' else cast(c.max_length as varchar(20)) end+')'
			when isnull(type_name(c.system_type_id), type_name(c.user_type_id)) in ('nvarchar') then '('+case when c.max_length = -1 then 'max' else cast(c.max_length/2 as varchar(20)) end+')'
			when isnull(type_name(c.system_type_id), type_name(c.user_type_id)) in ('varbinary') then '('+case when c.max_length = -1 then 'max' else cast(c.max_length as varchar(20)) end+')'
			else ''
		end DataType,
		cast(c.is_nullable as bit) IsNullable,
		cast(case when c.is_identity = 1 or c.is_computed = 1 or isnull(type_name(c.system_type_id), type_name(c.user_type_id)) = 'timestamp' then 1 else 0 end as bit) ReadOnly,
		c.collation_name as CollationName,
		cast(c.is_identity as bit) IsIdentity,
		cast(c.is_computed as bit) IsComputed,
		cc.definition + case when cc.is_persisted = 1 then ' Persisted' else ''  end ComputedColumnDefinition,
		cast(case when isnull(type_name(c.system_type_id), type_name(c.user_type_id)) = 'timestamp' then 1 else 0 end as bit) IsTimestamp,
		type_name(c.system_type_id) SystemType,
		type_name(c.user_type_id) UserType,
		c.max_length MaxLength,
		type_name(c.user_type_id) + 
		case 
			when type_name(c.user_type_id) in ('binary', 'char') then '('+cast(c.max_length as varchar(20))+')'
			when type_name(c.user_type_id)in ('nchar') then '('+cast(c.max_length/2 as varchar(20))+')'
			when type_name(c.user_type_id) in ('datetime2', 'datetimeoffset', 'time') then '('+cast(c.scale as varchar(20))+')'
			when type_name(c.user_type_id) in ('decimal', 'numeric') then '('+cast(c.precision as varchar(20))+','+cast(c.scale as varchar(20))+')'
			when type_name(c.user_type_id) in ('varchar') then '('+case when c.max_length = -1 then 'max' else cast(c.max_length as varchar(20)) end+')'
			when type_name(c.user_type_id) in ('nvarchar') then '('+case when c.max_length = -1 then 'max' else cast(c.max_length/2 as varchar(20)) end+')'
			when type_name(c.user_type_id) in ('varbinary') then '('+case when c.max_length = -1 then 'max' else cast(c.max_length as varchar(20)) end+')'
			else ''
		end DataTypeByUserType
	from sys.objects o
		inner join sys.all_columns c on c.object_id = o.object_id
		left outer join sys.indexes i on i.object_id = c.object_id and i.is_primary_key = 1
		left outer join sys.index_columns ic on ic.object_id = c.object_id and ic.index_id = i.index_id and ic.column_id = c.column_id
		left outer join sys.computed_columns cc on cc.object_id = c.object_id and cc.column_id = c.column_id
go
