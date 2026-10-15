create or alter  function z.fn_BuildQueryCopyLoginPermission
(
    @SourceLogin nvarchar(128) = null, 
    @TargetLogin nvarchar(128) = null
)
returns @ret table (Ordinal int identity(1,1), Type varchar(100), SQL nvarchar(max))
as
begin
	if @SourceLogin is null
		select @TargetLogin = null
	select @TargetLogin = isnull(@TargetLogin, @SourceLogin)

	;with x0 as
	(
		select	p.state_desc PermissionState, p.class_desc as ClassDesc, p.major_id MajorID, p.minor_id MinorID,
				replace(lower(string_agg(cast(p.permission_name as nvarchar(max)), ',')), ',', ', ') PermissionType,
				quotename(isnull(@TargetLogin, sp.name)) TargetLogin
		from sys.server_principals sp
			inner join sys.server_permissions p on p.grantee_principal_id = sp.principal_id
		where sp.name = @SourceLogin
		group by p.state_desc, p.class_desc, p.major_id, p.minor_id, quotename(isnull(@TargetLogin, sp.name))
	),
	x1 as
	(
		select TargetLogin, PermissionType, PermissionState, ClassDesc, MajorID, MinorID,
			quotename(object_name(MajorID)) MajorObjectName,
			quotename(schema_name(MajorID)) MajorSchemaName,
			case when MajorID > 0 then quotename(object_schema_name(MajorID)) + isnull('.' + quotename(object_name(MajorID)), '')+ isnull('(' + quotename(col_name(MajorID, MinorID)) + ')', '') end FullObjectName,
			d.type_desc ServerPrincipalType, 
			quotename(d.name) collate database_default ServerPrincipalName,
			quotename(e.name) EndpointName,
			quotename(ag.name) AGName
		from x0
			left join sys.server_principals d on d.principal_id = x0.MajorID
			left join sys.endpoints e on e.endpoint_id = x0.MajorID
			left join sys.availability_replicas r on r.replica_metadata_id = x0.MajorID
			left join sys.availability_groups ag on ag.group_id = r.group_id
			
	)
--	select distinct type_desc from sys.server_principals
	,
	x2 as
	(
		select 'Securable: ' + ClassDesc Type,
				case 
					when ClassDesc = 'SERVER' then 
						case 
							when PermissionState = 'GRANT' then 'grant ' + PermissionType + ' to ' + TargetLogin + ';'
							when PermissionState = 'GRANT_WITH_GRANT_OPTION' then 'grant ' + PermissionType + ' to ' + TargetLogin + ' with grant option;'
							when PermissionState = 'DENY' then 'deny ' + PermissionType + ' to ' + TargetLogin + ';'
							when PermissionState = 'REVOKE' then 'revoke ' + PermissionType + ' from ' + TargetLogin + ';'
						end
					when ClassDesc = 'ENDPOINT' then 
						case 
							when PermissionState = 'GRANT' then 'grant ' + PermissionType + ' on endpoint::' + EndpointName + ' to ' + TargetLogin + ';'
							when PermissionState = 'GRANT_WITH_GRANT_OPTION' then 'grant ' + PermissionType + ' on endpoint::' + EndpointName + ' to ' + TargetLogin + ' with grant option;'
							when PermissionState = 'DENY' then 'deny ' + PermissionType + ' on endpoint::' + EndpointName + ' to ' + TargetLogin + ';'
							when PermissionState = 'REVOKE' then 'revoke ' + PermissionType + ' on endpoint::' + EndpointName + ' from ' + TargetLogin + ';'
						end
					when ClassDesc = 'AVAILABILITY GROUP' then 
						case 
							when PermissionState = 'GRANT' then 'grant ' + PermissionType + ' on availability group::' + AGName + ' to ' + TargetLogin + ';'
							when PermissionState = 'GRANT_WITH_GRANT_OPTION' then 'grant ' + PermissionType + ' on availability group::' + AGName + ' to ' + TargetLogin + ' with grant option;'
							when PermissionState = 'DENY' then 'deny ' + PermissionType + ' on availability group::' + AGName + ' to ' + TargetLogin + ';'
							when PermissionState = 'REVOKE' then 'revoke ' + PermissionType + ' on availability group::' + AGName + ' from ' + TargetLogin + ';'
						end
					when ClassDesc = 'SERVER_PRINCIPAL' then
						case 
							when ServerPrincipalType in ('SERVER_ROLE') then
								case 
									when PermissionState = 'GRANT' then 'grant ' + PermissionType + ' on server role::' + ServerPrincipalName + ' to ' + TargetLogin + ';'
									when PermissionState = 'GRANT_WITH_GRANT_OPTION' then 'grant ' + PermissionType + ' on server role::' + ServerPrincipalName + ' to ' + TargetLogin + ' with grant option;'
									when PermissionState = 'DENY' then 'deny ' + PermissionType + ' on server role::' + ServerPrincipalName + ' to ' + TargetLogin + ';'
									when PermissionState = 'REVOKE' then 'revoke ' + PermissionType + ' on server role::' + ServerPrincipalName + ' from ' + TargetLogin + ';'
								end
							else
								case 
									when PermissionState = 'GRANT' then 'grant ' + PermissionType + ' on login::' + ServerPrincipalName + ' to ' + TargetLogin + ';'
									when PermissionState = 'GRANT_WITH_GRANT_OPTION' then 'grant ' + PermissionType + ' on login::' + ServerPrincipalName + ' to ' + TargetLogin + ' with grant option;'
									when PermissionState = 'DENY' then 'deny ' + PermissionType + ' on login::' + ServerPrincipalName + ' to ' + TargetLogin + ';'
									when PermissionState = 'REVOKE' then 'revoke ' + PermissionType + ' on login::' + ServerPrincipalName + ' from ' + TargetLogin + ';'
								end
						end
				end SQL
			from x1
	)
    insert into @ret(Type, SQL)
		select x2.Type, x2.SQL
		from x2
		where x2.SQL is not null

	insert into @ret(Type, SQL)
	select 'RoleMember', 'alter server role ' + quotename(r.name) + ' add member ' + quotename(p.name) + ';'
	from sys.server_principals p
		inner join sys.database_role_members rm on rm.member_principal_id = p.principal_id
		inner join sys.server_principals r on r.principal_id = rm.role_principal_id
	where p.name = @SourceLogin
	return
end