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
	@SemaphoreName nvarchar(200),
	@SuppressException bit = 0
)
as
begin
	set nocount on;
	if nullif(trim(@SemaphoreName), N'') is null return 0;
	declare	@ResourceInternal nvarchar(255), @LockOwner varchar(32), @Slot int,
			@Result int = 0, @Entry varbinary(5), @Key sysname;

	select	@Key = N'Semaphore-' + convert(nvarchar(11), db_id()) + N'-' + convert(varchar(64), hashbytes('SHA2_256', convert(varbinary(max), @SemaphoreName)), 2);

	begin try
		-- Context entry is owner(1: 0x01=Transaction, 0x00=Session) + slot(4).
		select	@Entry = convert(varbinary(5), session_context(@Key));
		if @Entry is null or datalength(@Entry) <> 5
			return 0;

		select	@LockOwner =	case
									when substring(@Entry, 1, 1) = 0x01 then 'Transaction'
									else 'Session'
								end,
				@Slot = convert(int, substring(@Entry, 2, 4));

		if @Slot > 0 and (@LockOwner = 'Session' or @@trancount > 0)
		begin
			select	@ResourceInternal = cast(@Slot as nvarchar(10)) + N'-' + @SemaphoreName;
			while applock_mode('public', @ResourceInternal, @LockOwner) <> 'NoLock'
			begin
				exec @Result = sys.sp_releaseapplock @Resource = @ResourceInternal, @LockOwner = @LockOwner;
				if @Result < 0
					return @Result;
			end;
		end;
		exec sys.sp_set_session_context @key = @Key, @value = null;
		return @Result;
	end try
	begin catch
		if @SuppressException = 0
			throw;
		print z.fn_GetFullErrorMessage();
		return -999;
	end catch
end
