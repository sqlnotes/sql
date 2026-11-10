/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/050-AsyncChannel/modules/1040%20Procedures/z.usp_AsyncChannelActivatorPoolRelease.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/050-AsyncChannel/docs/reference/z.usp_AsyncChannelActivatorPoolRelease.md

Releases one matching shared semaphore acquisition.
*/
create or alter procedure z.usp_AsyncChannelActivatorPoolRelease
(
	@ActivatorPoolID int
)
as
begin
	set nocount on
	declare @SemaphoreName nvarchar(200), @Result int
	if @ActivatorPoolID is null
		return
	select @SemaphoreName = N'ADPool/' + cast(@ActivatorPoolID as nvarchar(11))
	exec @Result = z.usp_ReleaseSemaphore @SemaphoreName = @SemaphoreName, @LockOwner = 'Session'
	return @Result
end
