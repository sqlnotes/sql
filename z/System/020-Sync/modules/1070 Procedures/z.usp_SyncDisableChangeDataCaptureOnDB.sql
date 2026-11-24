create or alter procedure z.usp_SyncDisableChangeDataCaptureOnDB
(
	@ServerName nvarchar(128) = null,
	@DatabaseName nvarchar(128) = null
)
as
begin
	set nocount on
	declare @SQL nvarchar(max)
	select @DatabaseName = isnull(@DatabaseName, db_name())
	select @SQL = 'if exists(select * from sys.databases where name = '+quotename(@DatabaseName , '''')+'and is_cdc_enabled = 1)
	begin
		if z.fn_IsAmazonRDS() = 1
		begin
			exec msdb.dbo.rds_cdc_disable_db '+quotename(@DatabaseName , '''')+'
		end
		else
		begin
			exec sys.sp_cdc_disable_db;
		end
	end
	'
	exec z.usp_SyncExecuteSQL @ServerName, @DatabaseName, @SQL
end

go
