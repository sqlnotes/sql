create or alter function z.fn_GetServiceJobName (@Name nvarchar(255))
returns nvarchar(128)
as
begin
	-- The complete generated name intentionally truncates to SQL Agent's 128-unit name limit.
	return 'z_' + quotename(db_name(), '(') + '_' + @Name
end
go
