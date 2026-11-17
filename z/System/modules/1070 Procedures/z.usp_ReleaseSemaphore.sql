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
	declare	@ContextKey sysname, @NameHash varchar(64), @ResourceInternal nvarchar(255),
			@LockOwner varchar(32) = 'Session', @Slot int, @Result int, @ReturnCode int = 0;
	select	@NameHash = convert(varchar(64), hashbytes('SHA2_256', convert(varbinary(max), @SemaphoreName)), 2);
	while @LockOwner is not null
	begin
		begin try
			select	@ContextKey = N'Semaphore-' + convert(nvarchar(11), db_id()) + N'-' + @LockOwner + N'-' + @NameHash,
					@ResourceInternal = null;
			select	@Slot = try_convert(int, session_context(@ContextKey));
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
					if applock_mode('public', @SemaphoreName, @LockOwner) = 'NoLock'
						exec sys.sp_set_session_context @key = @ContextKey, @value = null;
					else if @ReturnCode = 0 select @ReturnCode = -999;
				end
			end
			else
			begin
				exec sys.sp_set_session_context @key = @ContextKey, @value = null;
			end
		end try
		begin catch
			-- Cleanup must not throw or prevent attempting the other owner scope.
			if @ReturnCode = 0 select @ReturnCode = -999;
		end catch
		select	@LockOwner = case when @LockOwner = 'Session' then 'Transaction' end;
	end
	return @ReturnCode;
end
