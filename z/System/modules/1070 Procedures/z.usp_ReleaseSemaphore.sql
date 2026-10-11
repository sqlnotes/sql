create or alter procedure z.usp_ReleaseSemaphore
(
	@Resource nvarchar(200), --name of the semaphore
	@LockOwner varchar(32) = 'Transaction'
)
as
begin
	declare @ResourceInternal nvarchar(255) = cast(session_context('Semaphore-' + @Resource) as nvarchar(300))
	exec sp_releaseapplock @ResourceInternal, @LockOwner
	exec sp_releaseapplock @Resource, @LockOwner
end