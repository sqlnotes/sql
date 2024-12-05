set nocount on 
if user_id('MyTestSrc') is not null 
	drop user MyTestSrc
go
create user MyTestSrc without login;
go
grant view database state to MyTestSrc;
if not exists(
				select * 
				from z.fn_BuildQueryCopyUserPermission('MyTestsrc', null)
				where SQL = 'grant view database state to [MyTestsrc];'
			)
begin
	raiserror('Test01 failed for z.fn_BuildQueryCopyUserPermission', 16, 1)
end
go
--if object_id('z.testobj') is not null
go
if user_id('MyTestSrc') is not null 
	drop user MyTestSrc


--grant connect,view database state to [MyTestsrc];