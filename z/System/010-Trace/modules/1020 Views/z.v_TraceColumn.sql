/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/010-Trace/modules/1020%20Views/z.v_TraceColumn.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/010-Trace/docs/reference/supporting-objects.md#zv_tracecolumn

Lists SQL Trace column metadata and filtering capabilities.
*/
create or alter view z.v_TraceColumn
as
	select	c.trace_column_id ColumnID, c.name ColumnName, type_name SystemDataType,
			case c.type_name 
				when 'image' then 'varbinary'
				when 'text' then 'nvarchar'
				else c.type_name
			end DataType, 
			c.max_size MaxSize, 
			case c.type_name 
				when 'image' then 'varbinary(max)'
				when 'text' then 'nvarchar(max)'
				when 'nvarchar' then 'nvarchar(' + cast(c.max_size as varchar(20)) + ')'
				else c.type_name
			end Definition,
			c.is_filterable IsFilterable, c.is_repeatable IsRepeatable, c.is_repeated_base IsRepeatedBase
	from sys.trace_columns c 