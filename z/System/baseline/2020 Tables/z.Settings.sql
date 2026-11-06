/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/baseline/2020%20Tables/z.Settings.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/docs/reference/settings.md

Stores database-local settings as named Unicode text values.
*/
if object_id(N'z.Settings') is null
begin
	create table z.Settings
	(
		Name nvarchar(200) not null,
		Value nvarchar(max) not null,
		Description nvarchar(1000),
		constraint PK_z_Settings primary key clustered (Name)
	);
end
