/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/modules/1070%20Procedures/z.usp_ReleaseSemaphore.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/docs/reference/procedures.md#zusp_releasesemaphore

Releases an acquired semaphore slot using the session context and application locks.
*/
create or alter procedure z.usp_ReleaseSemaphore
(
	@SemaphoreName nvarchar(200)
)
as
begin
	set nocount on;
	if nullif(trim(@SemaphoreName), N'') is null return 0;
	declare	@ResourceInternal nvarchar(255), @ClearValue sql_variant,
			@LockOwner varchar(32) = 'Session', @Slot int, @Result int, @ReturnCode int = 0,
			@Hash binary(32), @Generation binary(8), @Entry varbinary(44),
			@Prefix nvarchar(64), @Key sysname, @Index int, @Legacy bit, @Found bit;
	select	@Hash = hashbytes('SHA2_256', convert(varbinary(max), @SemaphoreName));
	while @LockOwner is not null
	begin
		begin try
			select	@ResourceInternal = null;
			select	@Prefix = N'Semaphore-' + convert(nvarchar(11), db_id()) + N'-' + @LockOwner + N'-',
					@Generation = case when @LockOwner = 'Transaction' and @@trancount > 0 then convert(binary(8), current_transaction_id()) else 0x0000000000000000 end,
					@Slot = null, @Legacy = 0, @Found = 0, @Index = 1;
			select	@Key = @Prefix + convert(varchar(64), @Hash, 2);
			if session_context(@Key) is not null
			begin
				-- An active permit acquired with the former per-name key can still be released.
				select	@Slot = try_convert(int, session_context(@Key)), @Legacy = 1, @Found = 1;
			end
			else
			begin
				-- Pool entries are hash(32) + native slot(4) + transaction ID(8).
				-- A one-byte vacancy preserves the end marker (the first never-written key).
				while 1 = 1
				begin
					select	@Key = @Prefix + convert(nvarchar(11), @Index);
					select	@Entry = convert(varbinary(44), session_context(@Key));
					if @Entry is null break;
					if datalength(@Entry) = 44 and substring(@Entry, 1, 32) = @Hash
					begin
						select	@Found = 1, @Slot = case when substring(@Entry, 37, 8) = @Generation then convert(int, substring(@Entry, 33, 4)) end;
						break;
					end;
					select	@Index += 1;
				end;
			end;
			select	@ClearValue = case when @Legacy = 0 then 0x00 end;
			if @Slot > 0 select @ResourceInternal = cast(@Slot as nvarchar(10)) + N'-' + @SemaphoreName;
			-- Transaction context survives commit/rollback; probe only an active transaction.
			if @LockOwner = 'Session' or @@trancount > 0
			begin
				if @ResourceInternal is not null and applock_mode('public', @ResourceInternal, @LockOwner) <> 'NoLock'
				begin
					exec @Result = sys.sp_releaseapplock @Resource = @ResourceInternal, @LockOwner = @LockOwner;
					if @Result < 0 and @ReturnCode = 0 select @ReturnCode = @Result;
				end
				-- Retain the marker/context if the slot could not be fully released.
				if @ResourceInternal is not null and applock_mode('public', @ResourceInternal, @LockOwner) <> 'NoLock'
				begin
					if @ReturnCode = 0 select @ReturnCode = -999;
				end
				else
				begin
					-- An interrupted acquisition can leave a marker without a recorded slot.
					if applock_mode('public', @SemaphoreName, @LockOwner) <> 'NoLock'
					begin
						exec @Result = sys.sp_releaseapplock @Resource = @SemaphoreName, @LockOwner = @LockOwner;
						if @Result < 0 and @ReturnCode = 0 select @ReturnCode = @Result;
					end
					if applock_mode('public', @SemaphoreName, @LockOwner) <> 'NoLock'
					begin
						if @ReturnCode = 0 select @ReturnCode = -999;
					end
					else if @Found = 1 exec sys.sp_set_session_context @key = @Key, @value = @ClearValue;
				end
			end
			else if @Found = 1 exec sys.sp_set_session_context @key = @Key, @value = @ClearValue;
		end try
		begin catch
			-- Cleanup must not throw or prevent attempting the other owner scope.
			if @ReturnCode = 0 select @ReturnCode = -999;
		end catch
		select	@LockOwner = case when @LockOwner = 'Session' then 'Transaction' end;
	end
	return @ReturnCode;
end
