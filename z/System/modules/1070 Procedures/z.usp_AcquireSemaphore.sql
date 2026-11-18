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
	declare	@ResourceInternal nvarchar(255), @SessionKey sysname,
			@OtherOwner varchar(32), @ExistingSlot int, @OtherSlot int, @Slot int = 1,
			@Result int, @Remaining int, @MainAcquired bit = 0, @SlotAcquired bit = 0,
			@Started datetime2(3) = sysutcdatetime(), @Elapsed bigint,
			@Delay varchar(12), @SaveLegacy bit, @SaveGeneration binary(8), @SaveValue sql_variant,
			@Hash binary(32), @Generation binary(8), @Entry varbinary(44), @LookupOwner varchar(32),
			@Prefix nvarchar(64), @Key sysname, @FreeKey sysname, @Index int, @ResolvedSlot int, @Legacy bit;
	if nullif(trim(@SemaphoreName), N'') is null or @TotalCount is null or @TotalCount < 1
		throw 50000, 'A semaphore requires a nonempty name and positive capacity.', 1;
	if @LockOwner is null or @LockOwner not in ('Transaction', 'Session')
		throw 50000, 'Semaphore lock owner must be Transaction or Session.', 1;
	if @LockTimeout is null or @LockTimeout < -1
		throw 50000, 'Semaphore timeout must be -1 or nonnegative.', 1;
	select	@LockOwner = case when @LockOwner = 'Transaction' then 'Transaction' else 'Session' end;
	if @LockOwner = 'Transaction' and @@trancount = 0
		throw 50000, 'A transaction-owned semaphore requires an active transaction.', 1;
	select	@Hash = hashbytes('SHA2_256', convert(varbinary(max), @SemaphoreName)), @LookupOwner = @LockOwner,
			@OtherOwner = case @LockOwner when 'Session' then 'Transaction' else 'Session' end;
	while @LookupOwner is not null
	begin
		select	@Prefix = N'Semaphore-' + convert(nvarchar(11), db_id()) + N'-' + @LookupOwner + N'-',
				@Generation = case when @LookupOwner = 'Transaction' and @@trancount > 0 then convert(binary(8), current_transaction_id()) else 0x0000000000000000 end,
				@ResolvedSlot = null, @Legacy = 0, @Index = 1, @FreeKey = null;
		select	@Key = @Prefix + convert(varchar(64), @Hash, 2);
		if session_context(@Key) is not null
		begin
			-- An active permit acquired with the former per-name key can still be released.
			select	@ResolvedSlot = try_convert(int, session_context(@Key)), @Legacy = 1;
		end
		else
		begin
			-- Pool entries are hash(32) + native slot(4) + transaction ID(8).
			-- A one-byte vacancy preserves the end marker (the first never-written key).
			while 1 = 1
			begin
				select	@Key = @Prefix + convert(nvarchar(11), @Index);
				select	@Entry = convert(varbinary(44), session_context(@Key));
				if @Entry is null
				begin
					select	@Key = isnull(@FreeKey, @Key);
					break;
				end;
				if datalength(@Entry) = 44 and substring(@Entry, 1, 32) = @Hash
				begin
					select	@ResolvedSlot = case when substring(@Entry, 37, 8) = @Generation then convert(int, substring(@Entry, 33, 4)) end;
					break;
				end;
				if @FreeKey is null and (datalength(@Entry) = 1 or substring(@Entry, 37, 8) <> @Generation) select @FreeKey = @Key;
				select	@Index += 1;
			end;
		end;
		if @LookupOwner = @LockOwner
			select	@SessionKey = @Key, @ExistingSlot = @ResolvedSlot, @SaveLegacy = @Legacy, @SaveGeneration = @Generation;
		else select @OtherSlot = @ResolvedSlot;
		select	@LookupOwner = case when @LookupOwner = @LockOwner then @OtherOwner end;
	end;

	-- Concurrent MARS requests can independently select the same vacant entry
	-- from different snapshots. A per-name key keeps their writes independent.
	if @ExistingSlot is null and (connectionproperty('net_transport') = N'Session' or current_request_id() <> 0)
		select	@SaveLegacy = 1, @SessionKey = N'Semaphore-' + convert(nvarchar(11), db_id()) + N'-' + @LockOwner + N'-' + convert(varchar(64), @Hash, 2);

	if @ExistingSlot < 1 select @ExistingSlot = null;
	if @OtherSlot < 1 select @OtherSlot = null;

	-- A stale transaction value is harmless after commit/rollback. Never adopt a slot owned by another scope.
	if @OtherSlot > 0 and (@OtherOwner = 'Session' or @@trancount > 0)
	begin
		select	@ResourceInternal = cast(@OtherSlot as nvarchar(10)) + N'-' + @SemaphoreName;
		if applock_mode('public', @ResourceInternal, @OtherOwner) <> 'NoLock'
		begin
			print 'You have already acquired this semaphore with another owner.';
			return -1;
		end
	end
	if @ExistingSlot > 0
	begin
		select	@ResourceInternal = cast(@ExistingSlot as nvarchar(10)) + N'-' + @SemaphoreName;
		if applock_mode('public', @ResourceInternal, @LockOwner) = 'NoLock'
		begin
			select	@SaveValue = case when @SaveLegacy = 0 then 0x00 end;
			exec sys.sp_set_session_context @key = @SessionKey, @value = @SaveValue;
			select	@ExistingSlot = null;
		end
		else
			return @ExistingSlot;
	end
	if @ExistingSlot is null and applock_mode('public', @SemaphoreName, @LockOwner) = 'IntentExclusive'
	begin
		-- An interrupted acquisition may leave its marker without a recorded slot. Do not acquire a second slot.
		print 'This semaphore has an incomplete acquisition; release its session or transaction before retrying.';
		return -1;
	end

	begin try
		exec @Result = sys.sp_getapplock @Resource = @SemaphoreName, @LockMode = 'IntentExclusive', @LockOwner = @LockOwner, @LockTimeout = @LockTimeout;
		if @Result < 0 return @Result;
		select	@MainAcquired = 1, @Slot = 1;
		while 1 = 1
		begin
			if @LockTimeout > 0 and datediff_big(millisecond, @Started, sysutcdatetime()) >= @LockTimeout
			begin
				select	@Result = -1;
				break;
			end
			select	@ResourceInternal = cast(@Slot as nvarchar(10)) + N'-' + @SemaphoreName;
			exec @Result = sys.sp_getapplock @Resource = @ResourceInternal, @LockMode = 'Exclusive', @LockOwner = @LockOwner, @LockTimeout = 0;
			if @Result >= 0
			begin
				select	@SlotAcquired = 1;
				if @SaveLegacy = 1 select @SaveValue = @Slot;
				else select @SaveValue = @Hash + convert(binary(4), @Slot) + @SaveGeneration;
				exec sys.sp_set_session_context @key = @SessionKey, @value = @SaveValue;
				return @Slot;
			end
			if @Result <> -1 break;
			select	@Elapsed = datediff_big(millisecond, @Started, sysutcdatetime());
			if @LockTimeout > 0 and @Elapsed >= @LockTimeout break;
			if @Slot < @TotalCount
			begin
				select	@Slot = @Slot + 1;
				continue;
			end
			if @LockTimeout = 0 break;
			select	@Remaining = case when @LockTimeout = -1 then 4 else convert(int, @LockTimeout - @Elapsed) end;
			if @Remaining <= 0 break;
			select	@Delay = convert(varchar(12), dateadd(millisecond, iif(@Remaining < 4, @Remaining, 4), cast('00:00:00' as time(3))));
			waitfor delay @Delay;
			select	@Slot = 1;
		end
		-- A normal timeout/status failure releases this acquisition's marker.
		if @LockOwner = 'Session' or @@trancount > 0
			exec sys.sp_releaseapplock @Resource = @SemaphoreName, @LockOwner = @LockOwner;
		return @Result;
	end try
	begin catch
		if @LockOwner = 'Session' or @@trancount > 0
		begin
			if @SlotAcquired = 1 exec sys.sp_releaseapplock @Resource = @ResourceInternal, @LockOwner = @LockOwner;
			if @MainAcquired = 1 exec sys.sp_releaseapplock @Resource = @SemaphoreName, @LockOwner = @LockOwner;
		end;
		throw;
	end catch
end
