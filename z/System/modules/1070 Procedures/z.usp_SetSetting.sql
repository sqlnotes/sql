/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/modules/1070%20Procedures/z.usp_SetSetting.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/docs/reference/settings.md

Inserts or updates a setting, preserving an existing description when omitted.
*/
create or alter procedure z.usp_SetSetting
(
	@Name nvarchar(200),
	@Value nvarchar(max),
	@Description nvarchar(1000) = null
)
as
begin
	set nocount, xact_abort on;

	if @Name is null or trim(@Name) = N'' throw 50000, N'Setting name must not be null, empty or spaces only.', 1;
	if @Value is null throw 50000, N'Setting value must not be null.', 1;

	merge z.Settings with (holdlock) as t
	using (values (@Name, @Value, @Description)) as s (Name, Value, Description)
	on t.Name = s.Name
	when matched then
		update set Value = s.Value, Description = coalesce(s.Description, t.Description)
	when not matched then
		insert (Name, Value, Description) values (s.Name, s.Value, s.Description);
end
