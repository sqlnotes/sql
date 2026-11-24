create or alter procedure z.usp_SyncExecuteSQLScalarString @ServerName varchar(128), @DatabaseName varchar(128), @Query nvarchar(max), @Result nvarchar(max) output
as
begin
	set nocount on
	declare @t table(Result nvarchar(max))
	insert into @t
		exec z.usp_SyncExecuteSQL @ServerName, @DatabaseName, @Query
	select @Result = (select top 1 Result from @t)
end

go
