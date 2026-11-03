/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/010-Trace/baseline/2020%20Tables/z.TraceFilter.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/010-Trace/docs/reference/supporting-objects.md#ztracefilter

Stores ordered, typed filter predicates for logical trace definitions.
*/
if object_id(N'z.TraceFilter') is null
begin
	create table z.TraceFilter
	(
		TraceID int not null,
		FilterOrdinal int not null,
		ColumnID int not null,
		LogicOperator varchar(3) not null,
		ComparisonOperator varchar(8) not null,
		Value sql_variant not null,
		constraint PK_z_TraceFilter primary key (TraceID, FilterOrdinal)
	)
end
