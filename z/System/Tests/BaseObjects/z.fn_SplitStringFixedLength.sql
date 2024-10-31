declare @c int, @s int
select @c = count(*), @s = sum(len(Value)) 
from z.fn_SplitStringFixedLength(replicate(cast('a' as nvarchar(max)), 89011), 100)
option(maxrecursion 0)
if not( @c = 891 and @s = 89011)
begin
	raiserror('Test z.fn_SplitStringFixedLength failed.', 16, 1)
end
