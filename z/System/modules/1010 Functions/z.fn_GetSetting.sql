/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/modules/1010%20Functions/z.fn_GetSetting.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/docs/reference/settings.md

Returns a setting value, or null when the name is not found.
*/
create or alter function z.fn_GetSetting
(
	@Name nvarchar(200)
)
returns nvarchar(max)
as
begin
	return (select s.Value from z.Settings s where s.Name = @Name);
end
