/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/modules/1070%20Procedures/z.usp_PrintString.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/docs/reference/procedures.md#zusp_printstring

Prints text in line order using chunks of at most 4000 characters.
*/
create or alter procedure z.usp_PrintString (@str nvarchar(max))
as
begin
	declare @Line nvarchar(max)
	declare c cursor local for
		select l1.Value
		from z.fn_SplitLines(@str) l
			cross apply z.fn_SplitStringFixedLength(l.Value, 4000) l1
		order by l.Ordinal, l1.Ordinal
		option(maxrecursion 0)
	open c
	fetch next from c into @Line
	while @@fetch_status = 0
	begin
		print @Line
		fetch next from c into @Line
	end
	close c
	deallocate c
end
