create or alter  function z.fn_BuildQueryCopyUserPermission
(
    @SourceUser nvarchar(128) = null, 
    @TargetUser nvarchar(128) = null
)
returns @ret table (Ordinal int identity(1,1), Type varchar(100), SQL nvarchar(max))
as
begin
	if @SourceUser is null
		select @TargetUser = null
	select @TargetUser = isnull(@TargetUser, @SourceUser)
	;with x0 as 
	(
		select 
			lower(p.permission_name) PermissionType,
			p.state_desc as PermissionState,
			p.class_desc as ClassDesc,
			object_name(p.major_id) ObjectName,
			quotename(schema_name(p.major_id)) SchemaName,
			case when p.major_id > 0 then quotename(object_schema_name(p.major_id)) + isnull('.' + quotename(object_name(p.major_id)), '')+ isnull('.(' + quotename(col_name(p.major_id, p.minor_id)) + ')', '') end FullObjectName,
			quotename(isnull(@TargetUser, user_name(p.grantee_principal_id))) TargetUser
		from sys.database_permissions p
		where @SourceUser is null or 
			p.grantee_principal_id = user_id(@SourceUser)
	),
	x1 as
	(
		select 'Securable: ' + ClassDesc Type,
				case 
					when ClassDesc = 'DATABASE' then 
						case 
							when PermissionState = 'GRANT' then 'grant ' + PermissionType + ' to ' + TargetUser + ';'
							when PermissionState = 'GRANT_WITH_GRANT_OPTION' then 'grant ' + PermissionType + ' to ' + TargetUser + ' with grant option;'
							when PermissionState = 'DENY' then 'deny ' + PermissionType + ' to ' + TargetUser + ';'
							when PermissionState = 'REVOKE' then 'revoke ' + PermissionType + ' from ' + TargetUser + ';'
						end
					when ClassDesc = 'OBJECT_OR_COLUMN' then 
						case 
							when PermissionState = 'GRANT' then 'grant ' + PermissionType + ' on ' + FullObjectName + ' to ' + TargetUser + ';'
							when PermissionState = 'GRANT_WITH_GRANT_OPTION' then 'grant ' + PermissionType + ' on ' + FullObjectName + ' to ' + TargetUser + ' WITH GRANT OPTION;'
							when PermissionState = 'DENY' then 'deny ' + PermissionType + ' on ' + FullObjectName + ' to ' + TargetUser + ';'
							when PermissionState = 'REVOKE' then 'revoke ' + PermissionType + ' on ' + FullObjectName + ' to ' + TargetUser + ';'
						end
					when ClassDesc = 'SCHEMA' then 
						case 
							when PermissionState = 'GRANT' then 'grant ' + PermissionType + ' on schema::' + quotename(SchemaName) + ' to ' + TargetUser + ';'
							when PermissionState = 'GRANT_WITH_GRANT_OPTION' then 'grant ' + PermissionType + ' on schema::' + quotename(SchemaName) + ' to ' + TargetUser + ' WITH GRANT OPTION;'
							when PermissionState = 'DENY' then 'deny ' + PermissionType + ' on schema::' + quotename(SchemaName) + ' to ' + TargetUser + ';'
							when PermissionState = 'REVOKE' then 'revoke ' + PermissionType + ' on schema::' + quotename(SchemaName) + ' from ' + TargetUser + ';'
						end
					-- Other class types
					else 
						case 
							when PermissionState = 'GRANT' then 'grant ' + PermissionType + ' on ' + ClassDesc + '::' + isnull(quotename(ObjectName), '') + ' TO ' + TargetUser + ';'
							when PermissionState = 'GRANT_WITH_GRANT_OPTION' then 'grant ' + PermissionType + ' on ' + ClassDesc + '::' + ISNULL(quotename(ObjectName), '') + ' TO ' + TargetUser + ' WITH GRANT OPTION;'
							when PermissionState = 'DENY' then 'deny ' + PermissionType + ' on ' + ClassDesc + '::' + ISNULL(quotename(ObjectName), '') + ' TO ' + TargetUser + ';'
							when PermissionState = 'REVOKE' then 'revoke ' + PermissionType + ' on ' + ClassDesc + '::' + ISNULL(quotename(ObjectName), '') + ' FROM ' + TargetUser + ';'
						end
				end SQL
			from x0
	)
    insert into @ret(Type, SQL)
		select Type, SQL
		from x1
		where x1.SQL is not null
	return
end
go
select * from z.fn_BuildQueryCopyUserPermission(null, null)


--exec z.usp_RemoveSchemaZ 1