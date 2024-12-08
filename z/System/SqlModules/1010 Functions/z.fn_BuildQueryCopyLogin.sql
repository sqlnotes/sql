create or alter  function z.fn_BuildQueryCopyLogin
(
    @SourceLogin nvarchar(128) = null, 
    @TargetLogin nvarchar(128) = null
)
returns table
as
return(
		select	s.principal_id as ServerPrincipalID, s.name LoginName, s.type_desc LoginType,
		case  
			when s.type_desc in ('SQL_LOGIN') then
				'create login ' + quotename(isnull(@TargetLogin, s.name)) + ' with password = ' + convert(nvarchar(max), sl.password_hash, 1) + ' Hashed' 
				+ ', sid = ' + convert(nvarchar(max), s.sid, 1) +  isnull(', default_language = '+quotename(s.default_language_name), '')
				+ iif(sl.is_policy_checked = 1, ', check_policy = on', ', check_policy = off')
				+ iif(is_expiration_checked = 1, ', check_expiration = on', ', check_expiration = off') + ';'
			when s.type_desc in ('WINDOWS_LOGIN', 'WINDOWS_GROUP') then
				'create login ' + quotename(isnull(@TargetLogin, s.name)) + ' from windows;'
			when s.type_desc in ('SERVER_ROLE') then
				'create server role ' + quotename(isnull(@TargetLogin, s.name)) + ' ;'
		end SQL
	from sys.server_principals s
		left join sys.sql_logins sl on s.principal_id = sl.principal_id
	where s.type_desc in ('WINDOWS_GROUP', 'SQL_LOGIN', 'WINDOWS_LOGIN', 'SERVER_ROLE')
		and s.name = isnull(@SourceLogin, s.name)
		and s.is_fixed_role = 0
		and s.name not in ('public')
)
go



--drop server role aaa