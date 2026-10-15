create or alter procedure z.usp_RemapUserToLogin
(
	@UserNameContains nvarchar(128) = null,
	@UserNameReplacedWith nvarchar(128) = null,
	@LoginNameContains nvarchar(128) = null,
	@LoginNameReplacedWith nvarchar(128) = null
)
as
begin
	set nocount on
	declare @SQL nvarchar(max)
	declare c cursor local for
		select 'alter user ' + quotename(d.name) +' with login = ' + quotename(s.name) + ';'
		from sys.database_principals d
			 inner join sys.server_principals s on s.sid <> d.sid and d.type_desc = replace(s.type_desc, 'LOGIN', 'USER')
		where d.authentication_type_desc in ('WINDOWS', 'INSTANCE')
			and isnull(replace(d.name, @UserNameContains, isnull(@UserNameReplacedWith, @UserNameContains)), d.name) = isnull(replace(s.name, @LoginNameContains, @LoginNameReplacedWith), s.name)
	open c
	fetch next from c into @SQL
	while @@fetch_status = 0
	begin
		exec(@SQL)
		fetch next from c into @SQL
	end
	close c
	deallocate c
end