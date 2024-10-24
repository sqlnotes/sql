create or alter view z.v_ForeignKeys
as
	select 
			fk.object_id as ObjectID,
			object_schema_name(fk.object_id) SchemaName,
			fk.name as ObjectName,
			z.fn_GetExpectedName('ForeignKey',object_schema_name(fk.parent_object_id), object_name(fk.parent_object_id), p.ParentColumns, object_schema_name(fk.referenced_object_id), object_name(fk.referenced_object_id)) ExpectedObjectName,
			fk.parent_object_id ParentObjectID,
			object_name(fk.parent_object_id) ParentTableName,
			fk.referenced_object_id ReferenceObjectID,
			object_schema_name(fk.referenced_object_id) ReferencedSchemaName,
			object_name(fk.referenced_object_id) ReferencedTableName,
			p.ParentColumns,
			r.ReferencedColumns,
			fk.delete_referential_action_desc DeleteAction,
			fk.update_referential_action_desc UpdateAction,
			fk.is_system_named IsSystemNamed,
			fk.is_disabled IsDisabled,
			fk.is_not_trusted IsNotTusted
	from sys.foreign_keys fk
		cross apply (
						select stuff(
										(
											select ',' + quotename(col_name(fkc.parent_object_id, fkc.parent_column_id))
											from sys.foreign_key_columns fkc 
											where fkc.constraint_object_id = fk.object_id 
											order by fkc.constraint_column_id 
											for xml path(''), type
										).value('.', 'nvarchar(max)'), 
									1, 1, '') ParentColumns
					) p
		cross apply (
						select stuff(
										(
											select ',' + quotename(col_name(fkc.referenced_object_id, fkc.referenced_column_id))
											from sys.foreign_key_columns fkc 
											where fkc.constraint_object_id = fk.object_id 
											order by fkc.constraint_column_id 
											for xml path(''), type
										).value('.', 'nvarchar(max)'), 
									1, 1, '') ReferencedColumns
					) r
