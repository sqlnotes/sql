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
		select	p.state_desc PermissionState, p.class_desc as ClassDesc, p.major_id MajorID, p.minor_id MinorID,
				replace(lower(string_agg(cast(p.permission_name as nvarchar(max)), ',')), ',', ', ') PermissionType,
				quotename(isnull(@TargetUser, dp.name)) TargetUser
		from sys.database_principals dp
			inner join sys.database_permissions p on p.grantee_principal_id = dp.principal_id
		where dp.name = @SourceUser
		group by p.state_desc, p.class_desc, p.major_id, p.minor_id, quotename(isnull(@TargetUser, dp.name))
	),
	x1 as
	(
		select TargetUser, PermissionType, PermissionState, ClassDesc, MajorID, MinorID,
			quotename(object_name(MajorID)) MajorObjectName,
			quotename(schema_name(MajorID)) MajorSchemaName,
			case when MajorID > 0 then quotename(object_schema_name(MajorID)) + isnull('.' + quotename(object_name(MajorID)), '')+ isnull('(' + quotename(col_name(MajorID, MinorID)) + ')', '') end FullObjectName,
			d.type_desc DatabasePrincipalType, quotename(d.name) collate database_default DatabasePrincipalName,
			quotename(a.name) as AssemblyName,
			quotename(schema_name(t.schema_id)) + '.' + quotename(t.name) TypeName,
			quotename(schema_name(t.schema_id)) + '.' + quotename(x.name) as XMLSchemaCollectionName,
			quotename(mt.name) as MessageType,
			quotename(c.name) as ContractName,
			quotename(s.name) as ServiceName,
			quotename(b.name) as RemoteServiceBindingName,
			quotename(r.name) as RouteName,
			quotename(f.name) as FullTextCatalogName,
			quotename(sl.name) as FullTextCatalogStopListName,
			quotename(sk.name) as SymmetricKeyName,
			quotename(ak.name) as AsymmetricKeyName,
			quotename(cer.name) as CertificateName,
			quotename(sp.name) as SearchPropertyListName,
			sc.name as CredentialName,
			quotename(el.language) as LanguageName
		from x0
			left join sys.database_principals d on d.principal_id = x0.MajorID
			left join sys.assemblies a on a.assembly_id = x0.MajorID
			left join sys.types t on t.user_type_id = x0.MajorID
			left join sys.xml_schema_collections x on x.xml_collection_id = x0.MajorID
			left join sys.service_message_types mt on mt.message_type_id = x0.MajorID
			left join sys.service_contracts c on c.service_contract_id = x0.MajorID
			left join sys.services s on s.service_id = x0.MajorID
			left join sys.remote_service_bindings b on b.remote_service_binding_id = x0.MajorID
			left join sys.routes r on r.route_id = x0.MajorID
			left join sys.fulltext_catalogs f on f.fulltext_catalog_id = x0.MajorID
			left join sys.fulltext_stoplists sl on sl.stoplist_id = x0.MajorID
			left join sys.symmetric_keys sk on sk.symmetric_key_id =x0.MajorID
			left join sys.asymmetric_keys ak on ak.asymmetric_key_id = x0.MajorID
			left join sys.certificates cer on cer.certificate_id = x0.MajorID
			left join sys.registered_search_property_lists sp on sp.property_list_id = x0.MajorID
			left join sys.external_languages el on el.external_language_id = x0.MajorID
			left join sys.database_scoped_credentials sc on sc.credential_id = x0.MajorID
	),
	x2 as
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
							when PermissionState = 'GRANT_WITH_GRANT_OPTION' then 'grant ' + PermissionType + ' on ' + FullObjectName + ' to ' + TargetUser + ' with grant option;'
							when PermissionState = 'DENY' then 'deny ' + PermissionType + ' on ' + FullObjectName + ' to ' + TargetUser + ';'
							when PermissionState = 'REVOKE' then 'revoke ' + PermissionType + ' on ' + FullObjectName + ' to ' + TargetUser + ';'
						end
					when ClassDesc = 'SCHEMA' then 
						case 
							when PermissionState = 'GRANT' then 'grant ' + PermissionType + ' on schema::' + MajorSchemaName + ' to ' + TargetUser + ';'
							when PermissionState = 'GRANT_WITH_GRANT_OPTION' then 'grant ' + PermissionType + ' on schema::' + MajorSchemaName + ' to ' + TargetUser + ' with grant option;'
							when PermissionState = 'DENY' then 'deny ' + PermissionType + ' on schema::' + MajorSchemaName + ' to ' + TargetUser + ';'
							when PermissionState = 'REVOKE' then 'revoke ' + PermissionType + ' on schema::' + MajorSchemaName + ' from ' + TargetUser + ';'
						end
					when ClassDesc = 'DATABASE_PRINCIPAL' then
						case 
							when DatabasePrincipalType in ('APPLICATION_ROLE') then
								case 
									when PermissionState = 'GRANT' then 'grant ' + PermissionType + ' on application role::' + DatabasePrincipalName + ' to ' + TargetUser + ';'
									when PermissionState = 'GRANT_WITH_GRANT_OPTION' then 'grant ' + PermissionType + ' on application role::' + DatabasePrincipalName + ' to ' + TargetUser + ' with grant option;'
									when PermissionState = 'DENY' then 'deny ' + PermissionType + ' on application role::' + DatabasePrincipalName + ' to ' + TargetUser + ';'
									when PermissionState = 'REVOKE' then 'revoke ' + PermissionType + ' on application role::' + DatabasePrincipalName + ' from ' + TargetUser + ';'
								end
							when DatabasePrincipalType in ('DATABASE_ROLE') then
								case 
									when PermissionState = 'GRANT' then 'grant ' + PermissionType + ' on role::' + DatabasePrincipalName + ' to ' + TargetUser + ';'
									when PermissionState = 'GRANT_WITH_GRANT_OPTION' then 'grant ' + PermissionType + ' on role::' + DatabasePrincipalName + ' to ' + TargetUser + ' with grant option;'
									when PermissionState = 'DENY' then 'deny ' + PermissionType + ' on role::' + DatabasePrincipalName + ' to ' + TargetUser + ';'
									when PermissionState = 'REVOKE' then 'revoke ' + PermissionType + ' on role::' + DatabasePrincipalName + ' from ' + TargetUser + ';'
								end
							else
								case 
									when PermissionState = 'GRANT' then 'grant ' + PermissionType + ' on user::' + DatabasePrincipalName + ' to ' + TargetUser + ';'
									when PermissionState = 'GRANT_WITH_GRANT_OPTION' then 'grant ' + PermissionType + ' on user::' + DatabasePrincipalName + ' to ' + TargetUser + ' with grant option;'
									when PermissionState = 'DENY' then 'deny ' + PermissionType + ' on user::' + DatabasePrincipalName + ' to ' + TargetUser + ';'
									when PermissionState = 'REVOKE' then 'revoke ' + PermissionType + ' on user::' + DatabasePrincipalName + ' from ' + TargetUser + ';'
								end
						end
					when ClassDesc = 'ASSEMBLY' then 
						case 
							when PermissionState = 'GRANT' then 'grant ' + PermissionType + ' on assembly::' + AssemblyName + ' to ' + TargetUser + ';'
							when PermissionState = 'GRANT_WITH_GRANT_OPTION' then 'grant ' + PermissionType + ' on assembly::' + AssemblyName + ' to ' + TargetUser + ' with grant option;'
							when PermissionState = 'DENY' then 'deny ' + PermissionType + ' on assembly::' + AssemblyName + ' to ' + TargetUser + ';'
							when PermissionState = 'REVOKE' then 'revoke ' + PermissionType + ' on assembly::' + AssemblyName + ' from ' + TargetUser + ';'
						end
					when ClassDesc = 'TYPE' then 
						case 
							when PermissionState = 'GRANT' then 'grant ' + PermissionType + ' on type::' + TypeName + ' to ' + TargetUser + ';'
							when PermissionState = 'GRANT_WITH_GRANT_OPTION' then 'grant ' + PermissionType + ' on type::' + TypeName + ' to ' + TargetUser + ' with grant option;'
							when PermissionState = 'DENY' then 'deny ' + PermissionType + ' on type::' + TypeName + ' to ' + TargetUser + ';'
							when PermissionState = 'REVOKE' then 'revoke ' + PermissionType + ' on type::' + TypeName + ' from ' + TargetUser + ';'
						end
					when ClassDesc = 'XML_SCHEMA_COLLECTION' then 
						case 
							when PermissionState = 'GRANT' then 'grant ' + PermissionType + ' on xml schema collection::' + XMLSchemaCollectionName + ' to ' + TargetUser + ';'
							when PermissionState = 'GRANT_WITH_GRANT_OPTION' then 'grant ' + PermissionType + ' on xml schema collection::' + XMLSchemaCollectionName + ' to ' + TargetUser + ' with grant option;'
							when PermissionState = 'DENY' then 'deny ' + PermissionType + ' on xml schema collection::' + XMLSchemaCollectionName + ' to ' + TargetUser + ';'
							when PermissionState = 'REVOKE' then 'revoke ' + PermissionType + ' on xml schema collection::' + XMLSchemaCollectionName + ' from ' + TargetUser + ';'
						end
					when ClassDesc = 'MESSAGE_TYPE' then 
						case 
							when PermissionState = 'GRANT' then 'grant ' + PermissionType + ' on message type::' + MessageType + ' to ' + TargetUser + ';'
							when PermissionState = 'GRANT_WITH_GRANT_OPTION' then 'grant ' + PermissionType + ' on message type::' + MessageType + ' to ' + TargetUser + ' with grant option;'
							when PermissionState = 'DENY' then 'deny ' + PermissionType + ' on message type::' + MessageType + ' to ' + TargetUser + ';'
							when PermissionState = 'REVOKE' then 'revoke ' + PermissionType + ' on message type::' + MessageType + ' from ' + TargetUser + ';'
						end
					when ClassDesc = 'SERVICE_CONTRACT' then 
						case 
							when PermissionState = 'GRANT' then 'grant ' + PermissionType + ' on contract::' + ContractName + ' to ' + TargetUser + ';'
							when PermissionState = 'GRANT_WITH_GRANT_OPTION' then 'grant ' + PermissionType + ' on contract::' + ContractName + ' to ' + TargetUser + ' with grant option;'
							when PermissionState = 'DENY' then 'deny ' + PermissionType + ' on contract::' + ContractName + ' to ' + TargetUser + ';'
							when PermissionState = 'REVOKE' then 'revoke ' + PermissionType + ' on contract::' + ContractName + ' from ' + TargetUser + ';'
						end
					when ClassDesc = 'SERVICE' then 
						case 
							when PermissionState = 'GRANT' then 'grant ' + PermissionType + ' on service::' + ServiceName + ' to ' + TargetUser + ';'
							when PermissionState = 'GRANT_WITH_GRANT_OPTION' then 'grant ' + PermissionType + ' on SERVICE::' + ServiceName + ' to ' + TargetUser + ' with grant option;'
							when PermissionState = 'DENY' then 'deny ' + PermissionType + ' on service::' + ServiceName + ' to ' + TargetUser + ';'
							when PermissionState = 'REVOKE' then 'revoke ' + PermissionType + ' on service::' + ServiceName + ' from ' + TargetUser + ';'
						end
					when ClassDesc = 'REMOTE_SERVICE_BINDING' then 
						case 
							when PermissionState = 'GRANT' then 'grant ' + PermissionType + ' on remote service binding::' + RemoteServiceBindingName + ' to ' + TargetUser + ';'
							when PermissionState = 'GRANT_WITH_GRANT_OPTION' then 'grant ' + PermissionType + ' on remote service binding::' + RemoteServiceBindingName + ' to ' + TargetUser + ' with grant option;'
							when PermissionState = 'DENY' then 'deny ' + PermissionType + ' on remote service binding::' + RemoteServiceBindingName + ' to ' + TargetUser + ';'
							when PermissionState = 'REVOKE' then 'revoke ' + PermissionType + ' on remote service binding::' + RemoteServiceBindingName + ' from ' + TargetUser + ';'
						end
					when ClassDesc = 'ROUTE' then 
						case 
							when PermissionState = 'GRANT' then 'grant ' + PermissionType + ' on route::' + RouteName + ' to ' + TargetUser + ';'
							when PermissionState = 'GRANT_WITH_GRANT_OPTION' then 'grant ' + PermissionType + ' on route::' + RouteName + ' to ' + TargetUser + ' with grant option;'
							when PermissionState = 'DENY' then 'deny ' + PermissionType + ' on route::' + RouteName + ' to ' + TargetUser + ';'
							when PermissionState = 'REVOKE' then 'revoke ' + PermissionType + ' on route::' + RouteName + ' from ' + TargetUser + ';'
						end
					when ClassDesc = 'ROUTE' then 
						case 
							when PermissionState = 'GRANT' then 'grant ' + PermissionType + ' on route::' + RouteName + ' to ' + TargetUser + ';'
							when PermissionState = 'GRANT_WITH_GRANT_OPTION' then 'grant ' + PermissionType + ' on route::' + RouteName + ' to ' + TargetUser + ' with grant option;'
							when PermissionState = 'DENY' then 'deny ' + PermissionType + ' on route::' + RouteName + ' to ' + TargetUser + ';'
							when PermissionState = 'REVOKE' then 'revoke ' + PermissionType + ' on route::' + RouteName + ' from ' + TargetUser + ';'
						end
					when ClassDesc = 'FULLTEXT_CATALOG' then 
						case 
							when PermissionState = 'GRANT' then 'grant ' + PermissionType + ' on fulltext catalog::' + FullTextCatalogName + ' to ' + TargetUser + ';'
							when PermissionState = 'GRANT_WITH_GRANT_OPTION' then 'grant ' + PermissionType + ' on fulltext catalog::' + FullTextCatalogName + ' to ' + TargetUser + ' with grant option;'
							when PermissionState = 'DENY' then 'deny ' + PermissionType + ' on fulltext catalog::' + FullTextCatalogName + ' to ' + TargetUser + ';'
							when PermissionState = 'REVOKE' then 'revoke ' + PermissionType + ' on fulltext catalog::' + FullTextCatalogName + ' from ' + TargetUser + ';'
						end
					when ClassDesc = 'FULLTEXT_STOPLIST' then 
						case 
							when PermissionState = 'GRANT' then 'grant ' + PermissionType + ' on fulltext stoplist::' + FullTextCatalogStopListName + ' to ' + TargetUser + ';'
							when PermissionState = 'GRANT_WITH_GRANT_OPTION' then 'grant ' + PermissionType + ' on fulltext stoplist::' + FullTextCatalogStopListName + ' to ' + TargetUser + ' with grant option;'
							when PermissionState = 'DENY' then 'deny ' + PermissionType + ' on fulltext stoplist::' + FullTextCatalogStopListName + ' to ' + TargetUser + ';'
							when PermissionState = 'REVOKE' then 'revoke ' + PermissionType + ' on fulltext stoplist::' + FullTextCatalogStopListName + ' from ' + TargetUser + ';'
						end
					when ClassDesc = 'SYMMETRIC_KEYS' then 
						case 
							when PermissionState = 'GRANT' then 'grant ' + PermissionType + ' on symmetric key::' + SymmetricKeyName + ' to ' + TargetUser + ';'
							when PermissionState = 'GRANT_WITH_GRANT_OPTION' then 'grant ' + PermissionType + ' on symmetric key::' + SymmetricKeyName + ' to ' + TargetUser + ' with grant option;'
							when PermissionState = 'DENY' then 'deny ' + PermissionType + ' on symmetric key::' + SymmetricKeyName + ' to ' + TargetUser + ';'
							when PermissionState = 'REVOKE' then 'revoke ' + PermissionType + ' on symmetric key::' + SymmetricKeyName + ' from ' + TargetUser + ';'
						end
					when ClassDesc = 'ASYMMETRIC_KEY' then 
						case 
							when PermissionState = 'GRANT' then 'grant ' + PermissionType + ' on asymmetric key::' + AsymmetricKeyName + ' to ' + TargetUser + ';'
							when PermissionState = 'GRANT_WITH_GRANT_OPTION' then 'grant ' + PermissionType + ' on asymmetric key::' + AsymmetricKeyName + ' to ' + TargetUser + ' with grant option;'
							when PermissionState = 'DENY' then 'deny ' + PermissionType + ' on asymmetric key::' + AsymmetricKeyName + ' to ' + TargetUser + ';'
							when PermissionState = 'REVOKE' then 'revoke ' + PermissionType + ' on asymmetric key::' + AsymmetricKeyName + ' from ' + TargetUser + ';'
						end
					when ClassDesc = 'CERTIFICATE' then 
						case 
							when PermissionState = 'GRANT' then 'grant ' + PermissionType + ' on certificate::' + CertificateName + ' to ' + TargetUser + ';'
							when PermissionState = 'GRANT_WITH_GRANT_OPTION' then 'grant ' + PermissionType + ' on certificate::' + CertificateName + ' to ' + TargetUser + ' with grant option;'
							when PermissionState = 'DENY' then 'deny ' + PermissionType + ' on certificate::' + CertificateName + ' to ' + TargetUser + ';'
							when PermissionState = 'REVOKE' then 'revoke ' + PermissionType + ' on certificate::' + CertificateName + ' from ' + TargetUser + ';'
						end
					when ClassDesc = 'SEARCH_PROPERTY_LIST' then 
						case 
							when PermissionState = 'GRANT' then 'grant ' + PermissionType + ' on search property list::' + SearchPropertyListName + ' to ' + TargetUser + ';'
							when PermissionState = 'GRANT_WITH_GRANT_OPTION' then 'grant ' + PermissionType + ' on search property list::' + SearchPropertyListName + ' to ' + TargetUser + ' with grant option;'
							when PermissionState = 'DENY' then 'deny ' + PermissionType + ' on search property list::' + SearchPropertyListName + ' to ' + TargetUser + ';'
							when PermissionState = 'REVOKE' then 'revoke ' + PermissionType + ' on search property list::' + SearchPropertyListName + ' from ' + TargetUser + ';'
						end
					when ClassDesc = 'EXTERNAL_LANGUAGE' then 
						case 
							when PermissionState = 'GRANT' then 'grant ' + PermissionType + ' on external language::' + LanguageName + ' to ' + TargetUser + ';'
							when PermissionState = 'GRANT_WITH_GRANT_OPTION' then 'grant ' + PermissionType + ' on external language::' + LanguageName + ' to ' + TargetUser + ' with grant option;'
							when PermissionState = 'DENY' then 'deny ' + PermissionType + ' on external language::' + LanguageName + ' to ' + TargetUser + ';'
							when PermissionState = 'REVOKE' then 'revoke ' + PermissionType + ' on external language::' + LanguageName + ' from ' + TargetUser + ';'
						end	
					when ClassDesc = 'DATABASE_SCOPED_CREDENTIAL' then 
						case 
							when PermissionState = 'GRANT' then 'grant ' + PermissionType + ' on database scoped credential::' + CredentialName + ' to ' + TargetUser + ';'
							when PermissionState = 'GRANT_WITH_GRANT_OPTION' then 'grant ' + PermissionType + ' on database scoped credential::' + CredentialName + ' to ' + TargetUser + ' with grant option;'
							when PermissionState = 'DENY' then 'deny ' + PermissionType + ' on database scoped credential::' + CredentialName + ' to ' + TargetUser + ';'
							when PermissionState = 'REVOKE' then 'revoke ' + PermissionType + ' on database scoped credential::' + CredentialName + ' from ' + TargetUser + ';'
						end	
				end SQL
			from x1
	)
    insert into @ret(Type, SQL)
		select x2.Type, x2.SQL
		from x2
		where x2.SQL is not null

	insert into @ret(Type, SQL)
	select 'RoleMember', 'alter role ' + quotename(r.name) + ' add member ' + quotename(p.name) + ';'
	from sys.database_principals p
		inner join sys.database_role_members rm on rm.member_principal_id = p.principal_id
		inner join sys.database_principals r on r.principal_id = rm.role_principal_id
	where p.name = @SourceUser
	return
end
go