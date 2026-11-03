/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/010-Trace/modules/1020%20Views/z.v_TraceEventColumn.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/010-Trace/docs/reference/supporting-objects.md#zv_traceeventcolumn

Lists supported SQL Trace event and column combinations.
*/
create or alter view z.v_TraceEventColumn
as
	select te.trace_event_id TraceEventID, tc.name CategoryName, te.Name EventName, c.trace_column_id ColumnID, c.name ColumnName, c.type_name DataType, c.max_size MaxSize, c.is_filterable IsFilterable, c.is_repeatable IsRepeatable, c.is_repeated_base IsRepeatedBase
	from sys.trace_categories tc
		inner join sys.trace_events te on te.category_id = tc.category_id
		inner join sys.trace_event_bindings b on b.trace_event_id = te.trace_event_id
		inner join sys.trace_columns c on c.trace_column_id = b.trace_column_id