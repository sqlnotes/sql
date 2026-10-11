create or alter view z.v_CheckConstraints
as
	select 
			cc.object_id as ObjectID,
			object_schema_name(cc.object_id) SchemaName,
			cc.name as CheckConstraintName,
			cc.parent_object_id ParentObjectID,
			object_name(cc.parent_object_id) ParentObjectName,
			col_name(cc.parent_object_id, cc.parent_column_id) ParentColumnName,
			cc.definition Definition,
			cc.is_disabled IsDisabled,
			cc.is_system_named IsSystemNamed,
			cc.is_not_trusted IsNotTrusted
	from sys.check_constraints cc
