create or alter procedure z.usp_SyncExecuteSQLWithOutput @ServerName varchar(128), @DatabaseName varchar(128), @Query nvarchar(max), @Output1 nvarchar(max) = null output, @Output2 nvarchar(max) = null output
as
begin
	declare @Proc nvarchar(500), @Ret int
	if @DatabaseName is null
	begin
		exec @Ret = sp_executesql @Query, N'@Output1 nvarchar(max) output, @Output2 nvarchar(max) output', @Output1 output, @Output2 output
		return @Ret
	end
	select @Proc = isnull(quotename(@ServerName)+'.', '') + quotename(@DatabaseName) + '..sp_executesql'
	exec @Ret = @Proc @Query, N'@Output1 nvarchar(max) output, @Output2 nvarchar(max) output', @Output1 output, @Output2 output
	return @Ret
end

go
