create or alter view z.v_Indexes
as    
    select
        i.object_id ObjectID, i.index_id IndexID,
        object_schema_name(i.object_id) SchemaName, object_name(i.object_id) ObjectName, i.name IndexName,
        case
            when isnull(objectproperty(i.object_id, 'IsSchemaBound'), 0) = 1 and i.type_desc = 'CLUSTERED' then
                z.fn_GetExpectedName('PrimaryKey', object_schema_name(i.object_id), object_name(i.object_id), null, null, null)
            when i.is_primary_key = 0 and i.is_unique_constraint = 0 and i.type_desc not like '%COLUMNSTORE%' then
                z.fn_GetExpectedName('Index', object_schema_name(i.object_id), object_name(i.object_id), ic.IndexColumns, null, null)
            when i.is_primary_key = 1 then z.fn_GetExpectedName('PrimaryKey', object_schema_name(i.object_id), object_name(i.object_id), null, null, null)
            when i.is_unique_constraint = 1 then z.fn_GetExpectedName('UniqueKey', object_schema_name(i.object_id), object_name(i.object_id), ic.IndexColumns, null, null)
            when i.type_desc like '%COLUMNSTORE%' then z.fn_GetExpectedName('ColumnStore', object_schema_name(i.object_id), object_name(i.object_id), null, null, null)
		end ExpectedIndexName,
        i.type_desc IndexType,i.is_primary_key IsPrimaryKey, i.is_unique_constraint IsUniqueConstraint, i.is_unique IsUnique, i.ignore_dup_key,
        ic.IndexColumns,
        icd.IndexColumnDefinition,
        iic.IncludedColumns,
        i.filter_definition FilterDefinition,
        fg.name Partition,
        (select top 1 '(' + col_name(ic.object_id, ic.column_id) + ')' from sys.index_columns ic where ic.object_id = i.object_id and ic.index_id = i.index_id and ic.partition_ordinal > 0) PartitionColumn,
        (select top 1 p.data_compression_desc from sys.partitions p where p.data_compression in (1, 2) and p.object_id = i.object_id and p.index_id = i.index_id order by p.data_compression desc) Compression,
		i.is_padded IsPadded
    from sys.indexes i
		inner join sys.data_spaces fg on i.data_space_id = fg.data_space_id
		cross apply(
						select stuff(
										(
											select ','+quotename(col_name(ic.object_id, ic.column_id)) 
											from sys.index_columns ic 
											where ic.object_id = i.object_id 
												and ic.index_id = i.index_id 
												and ic.is_included_column = 0 
												and ic.key_ordinal > 0
											order by ic.key_ordinal 
											for xml path(''), type
										).value('.', 'varchar(max)'), 
									1, 1, '')
								IndexColumns
					) ic
		cross apply(
						select stuff(
										(
											select 
													','+quotename(col_name(ic.object_id, ic.column_id)) + case when ic.is_descending_key = 0 then ' asc' else ' desc' end 
											from sys.index_columns ic 
											where ic.object_id = i.object_id 
												and ic.index_id = i.index_id 
												and ic.is_included_column = 0 
												and ic.key_ordinal > 0
											order by ic.key_ordinal for xml path(''), type
										).value('.', 'varchar(max)'), 
									1, 1, '') IndexColumnDefinition
					) icd
		outer apply(
						select stuff(
										(
											select ','+quotename(col_name(ic.object_id, ic.column_id)) 
											from sys.index_columns ic 
											where ic.object_id = i.object_id 
												and ic.index_id = i.index_id 
												and ic.is_included_column = 1
											order by ic.key_ordinal 
											for xml path(''), type
										).value('.', 'varchar(max)'), 
									1, 1, '')
								IncludedColumns
					) iic
    where i.type_desc not in ('HEAP')
        and object_schema_name(i.object_id) <> 'sys'
        and exists(select * from sys.objects o where o.object_id = i.object_id and o.type_desc in ('USER_TABLE', 'VIEW'))
        and i.type_desc not in ('XML')
go
