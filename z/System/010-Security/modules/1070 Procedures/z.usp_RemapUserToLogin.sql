/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/010-Security/modules/1070%20Procedures/z.usp_RemapUserToLogin.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/010-Security/docs/reference/z.usp_RemapUserToLogin.md

Remaps database users to matching logins after applying name substitutions.
*/
create or alter procedure z.usp_RemapUserToLogin
(
	@UserNameContains nvarchar(128) = null,
	@UserNameReplacedWith nvarchar(128) = null,
	@LoginNameContains nvarchar(128) = null,
	@LoginNameReplacedWith nvarchar(128) = null
)
as
begin
	set nocount, xact_abort on;
	declare @SQL nvarchar(max);
	declare cUsers cursor local static for
		select 'alter user ' + quotename(d.name) + ' with login = ' + quotename(s.name) + ';'
		from sys.database_principals d
			inner join sys.server_principals s on s.sid <> d.sid and d.type_desc = replace(s.type_desc, 'LOGIN', 'USER')
		where d.authentication_type_desc in ('WINDOWS', 'INSTANCE')
			and isnull(replace(d.name, @UserNameContains, isnull(@UserNameReplacedWith, @UserNameContains)), d.name) = isnull(replace(s.name, @LoginNameContains, isnull(@LoginNameReplacedWith, @LoginNameContains)), s.name);
	open cUsers;
	fetch next from cUsers into @SQL;
	while @@fetch_status = 0
	begin
		exec(@SQL);
		fetch next from cUsers into @SQL;
	end
	close cUsers;
	deallocate cUsers;
end
