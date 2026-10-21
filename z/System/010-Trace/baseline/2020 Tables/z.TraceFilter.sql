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
