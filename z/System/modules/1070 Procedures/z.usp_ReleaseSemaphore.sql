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
	@LockOwner varchar(32) = 'Transaction'
)
as
begin
	set nocount on;
	declare @SessionKey sysname, @ResourceInternal nvarchar(255), @Slot int, @Result int;
	select @LockOwner = case @LockOwner when 'Transaction' then 'Transaction' when 'Session' then 'Session' else @LockOwner end;
	select @SessionKey = N'Semaphore-' + convert(nvarchar(11), db_id()) + N'-' + @LockOwner + N'-' + convert(varchar(64), hashbytes('SHA2_256', convert(varbinary(max), @SemaphoreName)), 2);
	select @Slot = try_convert(int, session_context(@SessionKey));
	if isnull(@Slot, 0) < 1
		throw 50000, 'No valid semaphore slot is stored in session context.', 1;
	select @ResourceInternal = cast(@Slot as nvarchar(10)) + N'-' + @SemaphoreName;
	exec @Result = sys.sp_releaseapplock @Resource = @ResourceInternal, @LockOwner = @LockOwner;
	if @Result < 0 return @Result;
	exec @Result = sys.sp_releaseapplock @Resource = @SemaphoreName, @LockOwner = @LockOwner;
	if applock_mode('public', @ResourceInternal, @LockOwner) = 'NoLock'
		exec sys.sp_set_session_context @key = @SessionKey, @value = null;
	return @Result;
end
