create or alter procedure z.usp_SyncExecuteSQL @ServerName varchar(128), @DatabaseName varchar(128), @Query nvarchar(max)
as
begin
	declare @Proc nvarchar(500), @Ret int
	if @DatabaseName is null
	begin
		exec @Ret = sp_executesql @Query
		return @Ret
	end
	select @Proc = isnull(quotename(@ServerName)+'.', '') + quotename(@DatabaseName) + '..sp_executesql'
	exec @Ret = @Proc @Query
	return @Ret
end

go
