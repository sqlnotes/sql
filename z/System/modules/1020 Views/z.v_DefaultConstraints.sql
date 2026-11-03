/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/modules/1020%20Views/z.v_DefaultConstraints.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/docs/reference/catalog.md#catalog-views

Exposes default-constraint definitions, parent columns and expected conventional names.
*/
create or alter view z.v_DefaultConstraints
as
	select 
			d.object_id as ObjectID,
			object_schema_name(d.object_id) SchemaName,
			d.name as DefaultName,
			z.fn_GetExpectedName('Default', object_schema_name(d.object_id), object_name(d.parent_object_id), col_name(d.parent_object_id, d.parent_column_id), null, null) ExpectedDefaultName,
			d.parent_object_id ParentObjectID,
			d.parent_column_id ParentColumnID,
			object_name(d.parent_object_id) ParentObjectName,
			col_name(d.parent_object_id, d.parent_column_id) ParentColumnName,
			d.definition Definition,
			d.is_system_named IsSystemNamed
	from sys.default_constraints d

