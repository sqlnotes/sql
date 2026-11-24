create or alter procedure z.usp_SyncReleaseLock
(
	@ConfigID int
)
as
begin
	set nocount on
	declare @Resource nvarchar(200) = cast(@ConfigID as nvarchar(20)) + '-z.usp_SyncGetLock'
	begin try
		exec sp_releaseapplock @Resource, N'Session'
	end try
	begin catch
	end catch
end


go
