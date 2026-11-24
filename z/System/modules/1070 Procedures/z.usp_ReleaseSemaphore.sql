/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/modules/1070%20Procedures/z.usp_ReleaseSemaphore.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/docs/reference/procedures.md#zusp_releasesemaphore

Releases the specified native semaphore slot held by the calling session or transaction.
*/
create or alter procedure z.usp_ReleaseSemaphore
(
	@SemaphoreName nvarchar(200),
	@SuppressException bit = 0,
	@Slot int = 1,
	@LockOwner varchar(32) = 'Transaction'
)
as
begin
	set nocount on;
	if nullif(trim(@SemaphoreName), N'') is null or isnull(@Slot, 0) < 1
		return 0;
	if @LockOwner is null or @LockOwner not in ('Transaction', 'Session')
		throw 50000, 'Semaphore lock owner must be Transaction or Session.', 1;
	select	@LockOwner = case when @LockOwner = 'Transaction' then 'Transaction' else 'Session' end;
	if @LockOwner = 'Transaction' and @@trancount = 0
		return 0;
	declare	@ResourceInternal nvarchar(255) = convert(nvarchar(10), @Slot) + N'-' + @SemaphoreName,
			@Marker nvarchar(255) = N'z.Semaphore:' + @SemaphoreName, @Result int = 0;

	begin try
		if applock_mode('public', @ResourceInternal, @LockOwner) = 'NoLock'
			return 0;
		while applock_mode('public', @ResourceInternal, @LockOwner) <> 'NoLock'
		begin
			exec @Result = sys.sp_releaseapplock @Resource = @ResourceInternal, @LockOwner = @LockOwner;
			if @Result < 0
				return @Result;
		end;
		if applock_mode('public', @Marker, @LockOwner) = 'Shared'
			exec @Result = sys.sp_releaseapplock @Resource = @Marker, @LockOwner = @LockOwner;
		return @Result;
	end try
	begin catch
		if @SuppressException = 0
			throw;
		print z.fn_GetFullErrorMessage();
		return -999;
	end catch;
end
