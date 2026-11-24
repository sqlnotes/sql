/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/modules/1070%20Procedures/z.usp_AcquireSemaphore.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/docs/reference/procedures.md#zusp_acquiresemaphore

Acquires a slot in a named capacity-limited semaphore using application locks.
*/
create or alter procedure z.usp_AcquireSemaphore
(
	@SemaphoreName nvarchar(200),
	@TotalCount int = 1,
	@LockOwner varchar(32) = 'Transaction',
	@LockTimeout int = -1
)
as
begin
	set nocount on;
	declare	@Marker nvarchar(255) = N'z.Semaphore:' + @SemaphoreName, @ResourceInternal nvarchar(255),
			@OtherOwner varchar(32), @HeldOwner varchar(32),
			@Slot int = 1, @FirstSlot int = 1, @LastSlot int = @TotalCount, @Result int, @Started datetime2(3) = sysutcdatetime();

	if nullif(trim(@SemaphoreName), N'') is null or @TotalCount is null or @TotalCount < 1
		throw 50000, 'A semaphore requires a nonempty name and positive capacity.', 1;
	if @LockOwner is null or @LockOwner not in ('Transaction', 'Session')
		throw 50000, 'Semaphore lock owner must be Transaction or Session.', 1;
	if @LockTimeout is null or @LockTimeout < -1
		throw 50000, 'Semaphore timeout must be -1 or nonnegative.', 1;
	select	@LockOwner = case when @LockOwner = 'Transaction' then 'Transaction' else 'Session' end;
	select	@OtherOwner = case when @LockOwner = 'Session' then 'Transaction' else 'Session' end;
	if @LockOwner = 'Transaction' and @@trancount = 0
		throw 50000, 'A transaction-owned semaphore requires an active transaction.', 1;

	if applock_mode('public', @Marker, @LockOwner) = 'Shared'
		select	@HeldOwner = @LockOwner;
	else if (@OtherOwner = 'Session' or @@trancount > 0)
		and applock_mode('public', @Marker, @OtherOwner) = 'Shared'
		select	@HeldOwner = @OtherOwner;

	if @HeldOwner is not null
	begin
		while 1 = 1
		begin
			select	@ResourceInternal = convert(nvarchar(10), @Slot) + N'-' + @SemaphoreName;
			if applock_mode('public', @ResourceInternal, @HeldOwner) = 'Exclusive'
			begin
				if @HeldOwner = @LockOwner
					return @Slot;
				-- Both owners of one connection use the same numbered slot.
				select	@FirstSlot = @Slot, @LastSlot = @Slot;
				break;
			end;
			if @Slot = @TotalCount
				throw 50000, 'The connection has a semaphore marker but no slot in the offered capacity. Release the original slot before reacquiring.', 1;
			select	@Slot += 1;
		end;
	end;

	while 1 = 1
	begin
		select	@ResourceInternal = convert(nvarchar(10), @Slot) + N'-' + @SemaphoreName;
		exec @Result = sys.sp_getapplock @Resource = @ResourceInternal, @LockMode = 'Exclusive', @LockOwner = @LockOwner, @LockTimeout = 0;
		if @Result >= 0
			break;
		if @Result <> -1
			return @Result;

		if @Slot < @LastSlot
		begin
			select	@Slot += 1;
			continue;
		end;
		if @LockTimeout >= 0 and datediff_big(millisecond, @Started, sysutcdatetime()) >= @LockTimeout
			return @Result;
		waitfor delay '00:00:00.004';
		select	@Slot = @FirstSlot;
	end;

	begin try
		exec @Result = sys.sp_getapplock @Resource = @Marker, @LockMode = 'Shared', @LockOwner = @LockOwner, @LockTimeout = 0;
	end try
	begin catch
		exec z.usp_ReleaseSemaphore @SemaphoreName = @SemaphoreName, @SuppressException = 1, @Slot = @Slot, @LockOwner = @LockOwner;
		throw;
	end catch;
	if @Result >= 0
		return @Slot;
	exec z.usp_ReleaseSemaphore @SemaphoreName = @SemaphoreName, @SuppressException = 1, @Slot = @Slot, @LockOwner = @LockOwner;
	return @Result;
end
