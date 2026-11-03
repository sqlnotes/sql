/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/modules/1020%20Views/z.v_CheckConstraints.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/docs/reference/catalog.md#catalog-views

Exposes check-constraint definitions, parent objects and disabled, system-named and trust flags.
*/
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
