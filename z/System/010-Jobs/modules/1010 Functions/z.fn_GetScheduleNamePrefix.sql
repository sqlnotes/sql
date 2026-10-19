create or alter function z.fn_GetScheduleNamePrefix()
returns nvarchar(300)
as
begin
	return N'Schema z: ' + quotename(db_name()) + N': ';
end;
go
