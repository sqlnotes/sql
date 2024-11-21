create or alter procedure z.usp_ChangeServerRoleOwnerToSA
(
	@CurrentOwnerName nvarchar(128) = null
)
as
begin
	declare @SQL nvarchar(max)
	declare c cursor local static for
		select 'alter authorization on server role :: ' + quotename(r.name ) + ' to sa;'
		from sys.server_principals r
		where r.type_desc = 'SERVER_ROLE'
			and r.owning_principal_id <> 1 -- not sa
			and (		@CurrentOwnerName is null 
					or exists(select * from sys.server_principals p where r.owning_principal_id = p.principal_id and p.name like @CurrentOwnerName)
				)
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