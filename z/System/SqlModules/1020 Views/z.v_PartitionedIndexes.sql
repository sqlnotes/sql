create or alter view z.v_PartitionedIndexes
as
select	p.object_id ObjectID,object_schema_name(p.object_id) SchemaName, object_name(p.object_id) ObjectName, 
		p.index_id IndexID, i.name IndexName, p.partition_number PartitionNumber, p.rows Rows, col_name(ic.object_id, ic.column_id) PartitionKeyName,
		ps.data_space_id DataSpaceID,ps.name PartitionSchemeName, fg.name FileGroupName,
		f1.function_id PartitionFunctionID,f1.name PartitionFunctionName, f1.boundary_value_on_right BoundaryValueOnRight,
		r.boundary_id BoundaryID, r.value BoundaryValue,
		cast(sql_variant_property(r.value,  'BaseType') as varchar(128)) BoundaryValueDataType, 
		cast(
				case 
					when sql_variant_property(r.value,  'BaseType') = 'bigint' then
						(
							select cast(dateadd(second, x0.seconds % 60, dateadd(minute, cast(x0.seconds / 60 as int), '1900-01-01')) as date) Date
							from (select cast(r.value as bigint)/268435456 as seconds) x0
						)
					when sql_variant_property(r.value,  'BaseType') in('date', 'datetime', 'datetime2') then
						r.value
					when sql_variant_property(r.value,  'BaseType') in('tinyint') then
						null
					else
						try_cast(r.value as date)
				end 
			as date) as BoundaryDateValue,  
		f1.fanout TotalPartitions
		
	from sys.partitions p
		inner join sys.indexes i on i.object_id = p.object_id and i.index_id = p.index_id
		left join sys.index_columns ic on ic.object_id = p.object_id and ic.index_id = p.index_id and ic.partition_ordinal = 1
		inner join sys.partition_schemes ps on ps.data_space_id = i.data_space_id
		inner join sys.partition_functions f1 on f1.function_id = ps.function_id
		left join sys.partition_functions f
			inner join sys.partition_range_values r on r.function_id = f.function_id
			on p.partition_number = r.boundary_id + 1 and ps.function_id = f.function_id
		outer apply(
							select top 1 d.name
							from sys.allocation_units au 
								inner join sys.data_spaces d on d.data_space_id = au.data_space_id
							where au.container_id = p.partition_id
					) fg
go