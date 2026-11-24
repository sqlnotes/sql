create or alter procedure z.usp_SyncEnableChangeTrackingOnDB
(
	@ServerName nvarchar(128) = null,
	@DatabaseName nvarchar(128) = null,
	@SQL nvarchar(max) = null output,
	@ExecuteSQL bit = 1
)
as
begin
	set nocount on
	select @SQL = 'declare @SQL nvarchar(max)
	if not exists(select * from sys.change_tracking_databases where database_id = db_id())
	begin
		select @SQL = ''alter database ''+quotename(db_name())+'' set change_tracking = on;''
		if @@trancount > 0
		begin
			print @SQL
			raiserror(''Could not enable change tracking within a transaciton on database. Please run the query above to enable change tracking. '', 16, 1)
		end
		exec(@SQL)
	end
	'
	begin try
	if @ExecuteSQL = 1
	begin
		exec z.usp_SyncExecuteSQL @ServerName, @DatabaseName, @SQL
	end
	end try
	begin catch
		throw;
	end catch
end

go
