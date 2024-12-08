set nocount on 
--Cleanup----
if exists(select* from sys.routes where name = 'SchemaZTestRoute') drop route SchemaZTestRoute;
if exists(select * from sys.remote_service_bindings where name = 'SchemaZTestRemoteServiceBinding')	drop remote service binding SchemaZTestRemoteServiceBinding;
if user_id('SchemaZTestUser') is not null drop user SchemaZTestUser;
if user_id('SchemaZTestUser1') is not null drop user SchemaZTestUser1;
if user_id('SchemaZTestUserApp') is not null drop application role SchemaZTestUserApp;
if schema_id('SchemaZTestSchema') is not null drop schema SchemaZTestSchema;
if object_id('z.SchemaZTestTable') is not null drop table z.SchemaZTestTable;
if object_id('z.usp_SchemaZTest') is not null drop proc z.usp_SchemaZTest;
if user_id('SchemaZTestRole') is not null drop role SchemaZTestRole;
if type_id('z.SchemaZTestType') is not null drop type z.SchemaZTestType;
if exists(select * from sys.xml_schema_collections where name = 'SchemaZTestXMLSchemaCollection' and schema_id = schema_id('z')) drop xml schema collection z.SchemaZTestXMLSchemaCollection;
if exists(select * from sys.fulltext_catalogs where name = 'SchemaZTestFullTextCatalog') drop fulltext catalog SchemaZTestFullTextCatalog;
if exists(select * from sys.fulltext_stoplists where name = 'SchemaZTestFullTextStopList') drop fulltext stoplist SchemaZTestFullTextStopList;
if exists(select * from sys.symmetric_keys where name = 'SchemaZTestSymmetricKey') drop symmetric key SchemaZTestSymmetricKey ;
if exists(select * from sys.asymmetric_keys where name = 'SchemaZTestAsymmetricKey') drop asymmetric key SchemaZTestAsymmetricKey;
if exists(select * from sys.certificates where name = 'SchemaZTestCertificate') drop certificate SchemaZTestCertificate;
if exists(select * from sys.registered_search_property_lists where name = 'SchemaZTestSearchPropertyList') drop search property list SchemaZTestSearchPropertyList;
if exists(select * from sys.database_scoped_credentials where name = 'SchemaZTestCredential') drop database scoped credential SchemaZTestCredential;
if exists(select *from sys.symmetric_keys where name = '##MS_DatabaseMasterKey##') and object_id('tempdb..#MasterKeyCreated') is not null 
begin
	drop master key;
	drop table #MasterKeyCreated
end
go



----Creation----
if not exists(select *from sys.symmetric_keys where name = '##MS_DatabaseMasterKey##')
begin
	create master key encryption by password = 'YourStrongPasswordHere!';
	--if object_id('tempdb..#MasterKeyCreated') is null
		create table #MasterKeyCreated(id int)
end

create user SchemaZTestUser without login;
create user SchemaZTestUser1 without login;
go
create schema SchemaZTestSchema;
go
create application role SchemaZTestUserApp with password='kdiifhakdfhjaiosr948rq94q!!@@'
create table z.SchemaZTestTable(ID int, value int, value1 nvarchar(max))
go
create procedure z.usp_SchemaZTest as 
go
create role SchemaZTestRole;
create type z.SchemaZTestType as table(id int)
create xml schema collection z.SchemaZTestXMLSchemaCollection AS N'<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema"><xs:element name="Item"><xs:complexType><xs:sequence><xs:element name="Name" type="xs:string" /></xs:sequence></xs:complexType></xs:element></xs:schema>';
create remote service binding SchemaZTestRemoteServiceBinding to service 'haha' with user=[SchemaZTestUser1], ANONYMOUS = on;
create route SchemaZTestRoute with service_name = 'TargetServiceName', address = 'TCP://TargetServerAddress:10';
create fulltext catalog SchemaZTestFullTextCatalog as default;
create fulltext stoplist SchemaZTestFullTextStopList;
create symmetric key SchemaZTestSymmetricKey with algorithm = aes_256 encryption by password = 'SymmetricKeyPassword123!';
create asymmetric key SchemaZTestAsymmetricKey with algorithm = rsa_2048 encryption by password = 'StrongPassword123!';
create certificate SchemaZTestCertificate encryption by password = 'pGFD4bb925DGvbd2439587y' with subject = 'My Test Certificate', start_date = '2024-01-01', expiry_date = '2034-01-01';
create search property list SchemaZTestSearchPropertyList;
create database scoped credential SchemaZTestCredential with identity = 'SchemaZTestCredential', secret = 'sv=2024-01-01&ss=bfqt&srt=sco&sp=rwdlacup&se=2024-12-31T23:59:59Z&st=2024-01-01T00:00:00Z&spr=https&sig=YOUR_STORAGE_KEY';
go
----test----
grant view database state to SchemaZTestUser;
grant  select, update on schema::SchemaZTestSchema to [SchemaZTestUser]
grant insert, delete on z.SchemaZTestTable to SchemaZTestUser
grant delete on z.SchemaZTestTable to SchemaZTestUser
grant update on z.SchemaZTestTable(value) to SchemaZTestUser
grant exec on z.usp_SchemaZTest to SchemaZTestUser
grant view definition on application role::SchemaZTestUserApp to [SchemaZTestUser]
grant view definition on user::SchemaZTestUser1 to [SchemaZTestUser]
grant alter on role::SchemaZTestRole to [SchemaZTestUser]
grant alter on assembly::[Microsoft.SqlServer.Types] to [SchemaZTestUser]
grant view definition on type::z.SchemaZTestType to [SchemaZTestUser]
grant execute on xml schema collection::z.SchemaZTestXMLSchemaCollection to [SchemaZTestUser];  
grant alter on message type::[http://schemas.microsoft.com/SQL/ServiceBroker/ServiceEcho/Echo] to [SchemaZTestUser];
grant alter on contract::[http://schemas.microsoft.com/SQL/Notifications/PostEventNotification] to [SchemaZTestUser];
grant alter on service::[http://schemas.microsoft.com/SQL/Notifications/EventNotificationService] to [SchemaZTestUser];
grant alter on remote service binding ::SchemaZTestRemoteServiceBinding to [SchemaZTestUser];
grant alter on route::SchemaZTestRoute to [SchemaZTestUser];
grant alter on fulltext catalog :: SchemaZTestFullTextCatalog to [SchemaZTestUser];
grant alter on fulltext stoplist:: SchemaZTestFullTextStopList to [SchemaZTestUser];
grant alter on symmetric key:: SchemaZTestSymmetricKey to [SchemaZTestUser];
grant alter on asymmetric key:: SchemaZTestAsymmetricKey to [SchemaZTestUser];
grant alter on certificate:: SchemaZTestCertificate to [SchemaZTestUser];

grant alter on search property list::SchemaZTestSearchPropertyList to [SchemaZTestUser];
grant alter on database scoped credential::SchemaZTestCredential to [SchemaZTestUser];
grant alter on external Language::R to [SchemaZTestUser];

alter role db_datareader add member [SchemaZTestUser];
--select *from sys.fulltext_catalogs
/*
select	*
from sys.database_permissions p
where p.grantee_principal_id = user_id('SchemaZTestUser')
*/



---Verify
exec z.usp_DropAllLocalTempTables
go
create table #Permissions1(Ordinal int, Type varchar(100), SQL nvarchar(max))

insert into #Permissions1(Ordinal, Type, SQL)
	select Ordinal, Type, SQL
	from z.fn_BuildQueryCopyUserPermission('SchemaZTestUser', null)

go
if user_id('SchemaZTestUser') is not null 
	drop user SchemaZTestUser
go
create user SchemaZTestUser without login;
go
declare @SQL nvarchar(max)
declare c cursor local for
	select SQL from #Permissions1
open c
fetch next from c into @SQL
while @@fetch_status = 0
begin
	--print @SQL
	exec(@SQL)
	fetch next from c into @SQL
end
close c
deallocate c
go

create table #Permissions2(Ordinal int, Type varchar(100), SQL nvarchar(max))
insert into #Permissions2(Ordinal, Type, SQL)
	select Ordinal, Type, SQL
	from z.fn_BuildQueryCopyUserPermission('SchemaZTestUser', null)


if exists(
			select SQL from #Permissions2
			except
			select SQL from #Permissions1
		)
begin
	raiserror('Test01 failed for z.fn_BuildQueryCopyUserPermission', 16, 1)
end
if exists(
			select SQL from #Permissions1
			except
			select SQL from #Permissions2
		)
begin
	raiserror('Test02 failed for z.fn_BuildQueryCopyUserPermission', 16, 1)
end

if (select count(*) from #Permissions2) <> 24
begin
	raiserror('Test03 failed for z.fn_BuildQueryCopyUserPermission', 16, 1)
end
if not exists(
	select *
	from sys.database_principals p
		inner join sys.database_role_members rm on rm.member_principal_id = p.principal_id
		inner join sys.database_principals r on r.principal_id = rm.role_principal_id
	where p.name = 'SchemaZTestUser'
	)
begin
	raiserror('Test04 failed for z.fn_BuildQueryCopyUserPermission', 16, 1)
end
----Cleanup----
if exists(select* from sys.routes where name = 'SchemaZTestRoute') drop route SchemaZTestRoute;
if exists(select * from sys.remote_service_bindings where name = 'SchemaZTestRemoteServiceBinding')	drop remote service binding SchemaZTestRemoteServiceBinding;
if user_id('SchemaZTestUser') is not null drop user SchemaZTestUser;
if user_id('SchemaZTestUser1') is not null drop user SchemaZTestUser1;
if user_id('SchemaZTestUserApp') is not null drop application role SchemaZTestUserApp;
if schema_id('SchemaZTestSchema') is not null drop schema SchemaZTestSchema;
if object_id('z.SchemaZTestTable') is not null drop table z.SchemaZTestTable;
if object_id('z.usp_SchemaZTest') is not null drop proc z.usp_SchemaZTest;
if user_id('SchemaZTestRole') is not null drop role SchemaZTestRole;
if type_id('z.SchemaZTestType') is not null drop type z.SchemaZTestType;
if exists(select * from sys.xml_schema_collections where name = 'SchemaZTestXMLSchemaCollection' and schema_id = schema_id('z')) drop xml schema collection z.SchemaZTestXMLSchemaCollection;
if exists(select * from sys.fulltext_catalogs where name = 'SchemaZTestFullTextCatalog') drop fulltext catalog SchemaZTestFullTextCatalog;
if exists(select * from sys.fulltext_stoplists where name = 'SchemaZTestFullTextStopList') drop fulltext stoplist SchemaZTestFullTextStopList;
if exists(select * from sys.symmetric_keys where name = 'SchemaZTestSymmetricKey') drop symmetric key SchemaZTestSymmetricKey ;
if exists(select * from sys.asymmetric_keys where name = 'SchemaZTestAsymmetricKey') drop asymmetric key SchemaZTestAsymmetricKey;
if exists(select * from sys.certificates where name = 'SchemaZTestCertificate') drop certificate SchemaZTestCertificate;
if exists(select * from sys.registered_search_property_lists where name = 'SchemaZTestSearchPropertyList') drop search property list SchemaZTestSearchPropertyList;
if exists(select * from sys.database_scoped_credentials where name = 'SchemaZTestCredential') drop database scoped credential SchemaZTestCredential;
if exists(select *from sys.symmetric_keys where name = '##MS_DatabaseMasterKey##') and object_id('tempdb..#MasterKeyCreated') is not null 
begin
	drop master key;
	drop table #MasterKeyCreated;
end
go