/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/010-Security/modules/1070%20Procedures/z.usp_FixOrphanUser.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/010-Security/docs/reference/z.usp_FixOrphanUser.md

Remaps SQL users with mismatched SIDs to same-named existing server logins.
*/
create or alter procedure z.usp_FixOrphanUser
(
	@UserName nvarchar(128) = null
)
as
begin
    set nocount on
    declare @SQL nvarchar(max)
    declare c cursor for
        select 'alter user ' + quotename(p.name)+ ' with login = ' + quotename(s.name collate database_default)+ ';'
        from sys.database_principals p
			inner join sys.server_principals s on s.name collate database_default = p.name  and s.sid <> p.sid
        where p.type_desc in ('SQL_USER')
			and (@UserName is null or p.name = @UserName)
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
