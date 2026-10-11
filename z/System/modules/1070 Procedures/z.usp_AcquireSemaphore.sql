create or alter procedure z.usp_AcquireSemaphore
(
	@Resource nvarchar(200), -- Name of the semaphore
	@TotalCount int = 1, -- Size of the semaphore, default it's binary semaphore
	@LockOwner varchar(32) = 'Transaction'
)
as
begin
	declare @ResourceInternal nvarchar(300), @SessionKey nvarchar(200) = 'Semaphore-' + @Resource, @SessionValue sql_variant
	declare @i int = 1, @ret int = -1
	if(applock_mode('public', @Resource, @LockOwner) = 'IntentExclusive')
	begin
		raiserror('You have acquired semaphore', 16,1)
		return -1;
	end
	exec sp_getapplock @Resource = @Resource,  @LockMode = 'IntentExclusive', @LockOwner = @LockOwner, @LockTimeout = -1
	while 1=1
	begin
		select @i = 1
		while @i <= @TotalCount
		begin
			select @ResourceInternal = cast(@i as varchar(10)) + '-' + @Resource
			exec @ret = sp_getapplock @Resource = @ResourceInternal,  @LockMode = 'Exclusive', @LockOwner = @LockOwner, @LockTimeout = 0
			if @ret >=0
			begin
				select @SessionValue = cast(@ResourceInternal as sql_variant)
				exec sp_set_session_context @key = @SessionKey, @value = @SessionValue
				return @i;
			end
			select @i = @i +1
		end
		waitfor delay '00:00:00.004' --sleep(4)
	end
end
go

