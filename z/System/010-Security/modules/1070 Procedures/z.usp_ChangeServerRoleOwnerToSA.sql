/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/010-Security/modules/1070%20Procedures/z.usp_ChangeServerRoleOwnerToSA.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/010-Security/docs/reference/z.usp_ChangeServerRoleOwnerToSA.md

Changes matching server-role ownership to the login named sa.
*/
create or alter procedure z.usp_ChangeServerRoleOwnerToSA
(
	@CurrentOwnerName nvarchar(128) = null
)
as
begin
	set nocount, xact_abort on;
	declare @SQL nvarchar(max);
	declare cRoles cursor local static for
		select 'alter authorization on server role :: ' + quotename(r.name) + ' to sa;'
		from sys.server_principals r
		where r.type_desc = 'SERVER_ROLE'
			and r.is_fixed_role = 0
			and r.owning_principal_id <> 1 -- not sa
			and (		@CurrentOwnerName is null
					or exists(select * from sys.server_principals p where r.owning_principal_id = p.principal_id and p.name like @CurrentOwnerName)
				);
	open cRoles;
	fetch next from cRoles into @SQL;
	while @@fetch_status = 0
	begin
		exec(@SQL);
		fetch next from cRoles into @SQL;
	end
	close cRoles;
	deallocate cRoles;
end
