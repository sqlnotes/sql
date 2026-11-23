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
	declare	@ResourceInternal nvarchar(255), @ExistingOwner varchar(32), @ExistingSlot int,
			@Slot int = 1, @Result int, @Started datetime2(3) = sysutcdatetime(),
			@OwnerByte binary(1), @Entry varbinary(5), @Key sysname;

	if nullif(trim(@SemaphoreName), N'') is null or @TotalCount is null or @TotalCount < 1
		throw 50000, 'A semaphore requires a nonempty name and positive capacity.', 1;
	if @LockOwner is null or @LockOwner not in ('Transaction', 'Session')
		throw 50000, 'Semaphore lock owner must be Transaction or Session.', 1;
	if @LockTimeout is null or @LockTimeout < -1
		throw 50000, 'Semaphore timeout must be -1 or nonnegative.', 1;
	select	@LockOwner = case when @LockOwner = 'Transaction' then 'Transaction' else 'Session' end;
	if @LockOwner = 'Transaction' and @@trancount = 0
		throw 50000, 'A transaction-owned semaphore requires an active transaction.', 1;

	-- Context entry is owner(1: 0x01=Transaction, 0x00=Session) + slot(4).
	select	@Key = N'Semaphore-' + convert(nvarchar(11), db_id()) + N'-' + convert(varchar(64), hashbytes('SHA2_256', convert(varbinary(max), @SemaphoreName)), 2),
			@OwnerByte = case when @LockOwner = 'Transaction' then 0x01 else 0x00 end;
	select	@Entry = convert(varbinary(5), session_context(@Key));

	if datalength(@Entry) = 5
	begin
		select	@ExistingOwner = case when substring(@Entry, 1, 1) = 0x01 then 'Transaction' else 'Session' end,
				@ExistingSlot = convert(int, substring(@Entry, 2, 4));
		if @ExistingSlot > 0 and (@ExistingOwner = 'Session' or @@trancount > 0)
		begin
			select	@ResourceInternal = cast(@ExistingSlot as nvarchar(10)) + N'-' + @SemaphoreName;
			if applock_mode('public', @ResourceInternal, @ExistingOwner) <> 'NoLock'
			begin
				if @ExistingOwner <> @LockOwner
				begin
					print 'You have already acquired this semaphore with another owner.';
					return -2;
				end;
				return @ExistingSlot;
			end;
		end;
		exec sys.sp_set_session_context @key = @Key, @value = null;
	end;

	begin try
		select	@Slot = 1, @Result = -1, @ResourceInternal = null;
		while 1 = 1
		begin
			select	@ResourceInternal = cast(@Slot as nvarchar(10)) + N'-' + @SemaphoreName,
					@Entry = @OwnerByte + convert(binary(4), @Slot);
			-- Record slot before acquiring so cancellation right after grant still leaves a releasable entry.
			exec sys.sp_set_session_context @key = @Key, @value = @Entry;
			exec @Result = sys.sp_getapplock @Resource = @ResourceInternal, @LockMode = 'Exclusive', @LockOwner = @LockOwner, @LockTimeout = 0;
			if @Result >= 0
				return @Slot;
			if @Result <> -1
				break;

			if @Slot < @TotalCount
			begin
				select	@Slot = @Slot + 1;
				continue;
			end;

			if @LockTimeout >= 0 and datediff_big(millisecond, @Started, sysutcdatetime()) >= @LockTimeout
				break;

			waitfor delay '00:00:00.004';
			select	@Slot = 1;
		end;
		exec sys.sp_set_session_context @key = @Key, @value = null;
		return @Result;
	end try
	begin catch
		if @ResourceInternal is not null and (@LockOwner = 'Session' or @@trancount > 0)
			and applock_mode('public', @ResourceInternal, @LockOwner) <> 'NoLock'
			exec sys.sp_releaseapplock @Resource = @ResourceInternal, @LockOwner = @LockOwner;
		exec sys.sp_set_session_context @key = @Key, @value = null;
		throw;
	end catch
end
