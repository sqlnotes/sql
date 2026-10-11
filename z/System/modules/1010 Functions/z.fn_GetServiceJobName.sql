create or alter function z.fn_GetServiceJobName (@Name nvarchar(255))
returns nvarchar(255)
as
begin
	return 'z_' + quotename(db_name(), '(') + '_' + @Name
end
go